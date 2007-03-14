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



#include "Dk.h"

#define DBG_MP_ALLOC_BOX(mp,len,tag) DBG_NAME(mp_alloc_box) (DBG_ARGS (mp), (len), (tag))
#define DBG_T_ALLOC_BOX(len,tag) DBG_NAME(t_alloc_box) (DBG_ARGS (len), (tag))

#ifdef LACERATED_POOL

#ifdef DEBUG /* Not MALLOC_DEBUG */
mem_pool_t * dbg_mem_pool_alloc (const char *file, int line)
#else
mem_pool_t * mem_pool_alloc (void)
#endif
{
  NEW_VARZ (mem_pool_t, mp);
  mp->mp_allocs = (caddr_t *)dk_alloc (sizeof (caddr_t) * 0x100);
  mp->mp_size = 0x100;
#ifdef DEBUG /* Not MALLOC_DEBUG */
  mp->mp_alloc_file = (char *)file;
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
  dk_free ((caddr_t) mp->mp_allocs, mp->mp_size * sizeof (caddr_t));
  dk_free ((caddr_t) mp, sizeof (mem_pool_t));
}


void mp_alloc_box_assert (mem_pool_t * mp, caddr_t box)
{
#ifdef DOUBLE_ALIGN
  const char *err = dbg_find_allocation_error (box-8, mp);
#else
  char *err = dbg_find_allocation_error (box-4, mp);
#endif
  if (NULL != err)
  GPF_T1 (err);
}

#else



#define MP_BLOCK_SIZE (4096 - ALIGN_8((sizeof (mem_block_t))))

#ifdef DEBUG /* Not MALLOC_DEBUG */
mem_pool_t * dbg_mem_pool_alloc (const char *file, int line)
#else
mem_pool_t * mem_pool_alloc (void)
#endif
{
  NEW_VARZ (mem_pool_t, mp);
  mp->mp_block_size = ALIGN_8(4096);
#ifdef DEBUG /* Not MALLOC_DEBUG */
  mp->mp_alloc_file = (char *)file;
  mp->mp_alloc_line = line;
#endif
  return mp;
}


void
mp_free (mem_pool_t * mp)
{
  mem_block_t * mb = mp->mp_first, *next;
  while (mb)
    {
      next = mb->mb_next;
      dk_free ((caddr_t) mb, mb->mb_size);
      mb = next;
    }
  dk_free ((caddr_t) mp, sizeof (mem_pool_t));
}


size_t
mp_size (mem_pool_t * mp)
{
  size_t sz = 0;
  mem_block_t * mb = mp->mp_first, *next;
  while (mb)
    {
      next = mb->mb_next;
      sz += mb->mb_size;
      mb = next;
    }
  return sz;
}

#endif

caddr_t DBG_NAME(mp_alloc_box) (DBG_PARAMS mem_pool_t * mp, size_t len1, dtp_t dtp)
{
  dtp_t *ptr;
#ifdef LACERATED_POOL
#ifdef DOUBLE_ALIGN
  size_t len = ALIGN_8(len1+8);
#else
  size_t len = ALIGN_4(len1+4);
#endif
  caddr_t new_alloc = DBG_NAME(mallocp) (DBG_ARGS len, mp);
  mp->mp_bytes += len;
  if (mp->mp_fill >= mp->mp_size)
    {
      caddr_t *newallocs;
      mp->mp_size *= 2;
      newallocs = (caddr_t *)dk_alloc(sizeof(caddr_t) * mp->mp_size);
      memcpy (newallocs, mp->mp_allocs, sizeof(caddr_t) * mp->mp_fill);
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
  size_t len = ALIGN_8(len1+bh_len);
  mem_block_t * mb = NULL;
  mem_block_t * f = mp->mp_first;
  size_t hlen = ALIGN_8((sizeof (mem_block_t))); /* we can have a doubles so structure also must be aligned */
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
  ptr = ((dtp_t* ) mb) + mb->mb_fill + (bh_len / 2);
  mb->mb_fill += len;
#endif
#ifndef LACERATED_POOL
  if (bh_len)
    {
#endif
  (ptr++)[0] = (dtp_t) (len1 & 0xff);
  (ptr++)[0] = (dtp_t) (len1 >> 8);
  (ptr++)[0] = (dtp_t) (len1 >> 16);
  (ptr++)[0] = dtp;
#ifndef LACERATED_POOL
    }
#endif
  memset (ptr, 0, len1);
  return ((caddr_t) ptr);
}

caddr_t DBG_NAME(mp_box_string) (DBG_PARAMS mem_pool_t * mp, const char * str)
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
DBG_NAME(mp_box_dv_short_nchars) (DBG_PARAMS mem_pool_t * mp, const char *buf, size_t buf_len)
{
  box_t box;
  box = DBG_MP_ALLOC_BOX (mp, buf_len+1, DV_SHORT_STRING);
  memcpy (box, buf, buf_len);
  ((char *)box)[buf_len] = '\0';
  return box;
}


caddr_t DBG_NAME(mp_box_substr) (DBG_PARAMS mem_pool_t * mp, ccaddr_t str, int n1, int n2)
{
  int lstr = (int)(box_length (str)) - 1;
  int lres;
  char * res;
  if (n2 > lstr)
    n2 = lstr;
  lres = n2 - n1;
  if (lres <= 0)
    return (DBG_NAME(mp_box_string) (DBG_ARGS mp, ""));
  res = DBG_NAME(mp_alloc_box) (DBG_ARGS mp, lres + 1, DV_SHORT_STRING);
  memcpy (res, str + n1, lres);
  res[lres] = 0;
  return res;
}


extern box_copy_f box_copier[256];
extern box_tmp_copy_f box_tmp_copier[256];


caddr_t DBG_NAME(mp_box_copy) (DBG_PARAMS mem_pool_t * mp, caddr_t box)
{
  dtp_t dtp;
  if (!IS_BOX_POINTER (box))
    return box;
  dtp = box_tag (box);
  switch (dtp)
    {
    case DV_UNAME:
      box_dv_uname_make_immortal (box);
      return box;
    case DV_REFERENCE:
      return box;
    case DV_XPATH_QUERY:
      return box;
    default:
      {
        caddr_t cp;
	if (box_copier[dtp])
	  {
	    if (box_tmp_copier[dtp])
	      return box_tmp_copier[dtp] (mp, box);
	    GPF_T1 ("not supposed to make a tmp pool copy of this copiable dtp");
	    return NULL;
	  }
	cp = DBG_MP_ALLOC_BOX (mp, box_length (box), box_tag (box));
        memcpy (cp, box, box_length (box));
        return cp;
      }
    }
}


caddr_t DBG_NAME(mp_box_copy_tree) (DBG_PARAMS mem_pool_t * mp, caddr_t box)
{
  dtp_t dtp;
  if (!IS_BOX_POINTER (box))
    return box;
  dtp = box_tag (box);
  if (IS_NONLEAF_DTP(dtp))
    {
      int inx, len = BOX_ELEMENTS (box);
      caddr_t * cp= (caddr_t *) DBG_NAME (mp_box_copy) (DBG_ARGS mp, box);
      for (inx = 0; inx < len; inx++)
	cp[inx] = DBG_NAME (mp_box_copy_tree) (DBG_ARGS mp, cp[inx]);
      return ((caddr_t) cp);
    }
  if (DV_UNAME == dtp)
    {
      box_dv_uname_make_immortal (box);
      return box;
    }
  return box;
}


caddr_t DBG_NAME(mp_full_box_copy_tree) (DBG_PARAMS mem_pool_t * mp, caddr_t box)
{
  dtp_t dtp;
  caddr_t * cp;
  if (!IS_BOX_POINTER (box))
    return box;
  dtp = box_tag (box);
  switch (dtp)
    {
    case DV_UNAME:
      box_dv_uname_make_immortal (box);
      return box;
    case DV_REFERENCE:
      return box;
    case DV_XPATH_QUERY:
      return box;
    }
  cp= (caddr_t *) DBG_NAME (mp_box_copy) (DBG_ARGS mp, box);
  if (IS_NONLEAF_DTP(dtp))
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
	  GPF_T1 ("copy tree of non box"); /* dereference to see it is something */
    }
  va_end (ap);
  return ((caddr_t *) box);
}

caddr_t DBG_NAME(mp_box_num) (DBG_PARAMS mem_pool_t * mp, ptrlong n)
{
  box_t *box;
  if (!IS_POINTER (n))
    return (box_t) n;
  box = (box_t *) DBG_NAME(mp_alloc_box) (DBG_ARGS mp, sizeof (box_t), DV_LONG_INT);
  *box = (box_t) n;
  return (caddr_t) box;
}

caddr_t DBG_NAME(t_box_num) (DBG_PARAMS ptrlong n)
{
  box_t *box;

  if (!IS_POINTER (n))
    return (box_t) n;

  box = (box_t *) DBG_T_ALLOC_BOX (sizeof (box_t), DV_LONG_INT);
  *box = (box_t) n;

  return (caddr_t) box;
}

caddr_t DBG_NAME(t_box_num_and_zero) (DBG_PARAMS ptrlong n)
{
  box_t *box;

  if (!IS_POINTER (n) && n != 0)
    return (box_t) n;

  box = (box_t *) DBG_T_ALLOC_BOX (sizeof (box_t), DV_LONG_INT);
  *box = (box_t) n;

  return (caddr_t) box;
}

box_t DBG_NAME(t_box_double) (DBG_PARAMS double d)
{
  double *box = (double *) DBG_T_ALLOC_BOX (sizeof (double), DV_DOUBLE_FLOAT);
  *box = d;
  return (box_t) box;
}

box_t DBG_NAME(t_box_float) (DBG_PARAMS float d)
{
  float *box = (float *) DBG_T_ALLOC_BOX (sizeof (float), DV_SINGLE_FLOAT);
  *box = d;
  return (box_t) box;
}



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
#ifdef MALLOC_DEBUG
      if (IS_BOX_POINTER (child))
	mp_alloc_box_assert (THR_TMP_POOL, child);
#endif
      box[inx] = child;
    }
  va_end (ap);
  return ((caddr_t *) box);
}


caddr_t *
t_list_concat_tail (caddr_t list, long n,...)
{
  caddr_t *res;
  va_list ap;
  int old_elems = ((NULL == list) ? 0 : BOX_ELEMENTS (list));
  int inx;
#ifdef DEBUG
  if ((NULL != list) && (DV_ARRAY_OF_POINTER != DV_TYPE_OF (list)) && (DV_ARRAY_OF_LONG != DV_TYPE_OF (list)))
    GPF_T1("Bad type of first arg of t_list_concat_tail()");
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
      for (inx = old_elems + n; inx--; /* no step */)
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
  res = t_alloc_box (len1+len2, box_tag (list1));
  memcpy (res, list1, len1);
  memcpy (res + len1, list2, len2);
  return (caddr_t *)res;
}


caddr_t *
t_list_remove_nth (caddr_t list, int pos)
{
  int len = BOX_ELEMENTS_INT (list);
  caddr_t *res;
  if ((pos < 0) || (pos >= len))
    GPF_T1("t_list_remove_nth (): bad index");
  res = (caddr_t *)t_alloc_box ((len-1) * sizeof (ptrlong), box_tag (list));
  memcpy (res, list, pos * sizeof (ptrlong));
  memcpy (res + pos, ((caddr_t *)list) + pos + 1, (len - (pos + 1)) * sizeof (ptrlong));
  return res;
}

caddr_t *
t_list_insert_before_nth (caddr_t list, caddr_t new_item, int pos)
{
  int len = BOX_ELEMENTS_INT (list);
  caddr_t *res;
  if ((pos < 0) || (pos > len))
    GPF_T1("t_list_insert_before_nth (): bad index");
  res = (caddr_t *)t_alloc_box ((len+1) * sizeof (ptrlong), box_tag (list));
  memcpy (res, list, pos * sizeof (ptrlong));
  res [pos] = new_item;
  memcpy (res + pos + 1, ((caddr_t *)list) + pos, (len - pos) * sizeof (ptrlong));
  return res;
}

caddr_t *
t_list_insert_many_before_nth (caddr_t list, caddr_t *new_items, int ins_count, int pos)
{
  int len = BOX_ELEMENTS_INT (list);
  caddr_t *res;
  if ((pos < 0) || (pos > len))
    GPF_T1("t_list_insert_before_nth (): bad index");
  res = (caddr_t *)t_alloc_box ((len + ins_count) * sizeof (ptrlong), box_tag (list));
  memcpy (res, list, pos * sizeof (ptrlong));
  memcpy (res + pos, new_items, ins_count * sizeof (ptrlong));
  memcpy (res + pos + ins_count, ((caddr_t *)list) + pos, (len - pos) * sizeof (ptrlong));
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


void DBG_NAME(mp_set_push) (DBG_PARAMS mem_pool_t *mp, dk_set_t * set, void* elt)
{
  s_node_t *s = (s_node_t *) DBG_NAME(mp_alloc_box)(DBG_ARGS mp, sizeof (s_node_t), DV_NON_BOX);
  s->data = elt;
  s->next = *set;
  *set = s;
}


dk_set_t DBG_NAME(t_cons) (DBG_PARAMS void* car, dk_set_t cdr)
{
  s_node_t * s = (s_node_t *) t_alloc_box (sizeof (s_node_t), DV_NON_BOX);
  s->data = car;
  s->next = cdr;
  return s;
}


void DBG_NAME(t_set_push) (DBG_PARAMS dk_set_t * set, void* elt)
{
  *set = DBG_NAME(t_cons) (DBG_ARGS elt, *set);
}


void * DBG_NAME(t_set_pop) (DBG_PARAMS s_node_t ** set)
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
DBG_NAME(t_set_pushnew) (DBG_PARAMS s_node_t ** set, void *item)
{
  if (!dk_set_member (*set, item))
    {
      s_node_t * newn = (s_node_t *) t_alloc_box (sizeof (s_node_t), DV_NON_BOX);
      newn->next = *set;
      newn->data = item;
      *set = newn;
      return 1;
    }
  return 0;
}


int
DBG_NAME(t_set_push_new_string) (DBG_PARAMS s_node_t ** set, void *item)
{
  if (0 > dk_set_position_of_string (*set, item))
    {
      s_node_t * newn = (s_node_t *) t_alloc_box (sizeof (s_node_t), DV_NON_BOX);
      newn->next = *set;
      newn->data = item;
      *set = newn;
      return 1;
    }
  return 0;
}


dk_set_t DBG_NAME(t_set_union) (DBG_PARAMS dk_set_t s1, dk_set_t s2)
{
  dk_set_t un = s2;
  DO_SET (caddr_t, elt, &s1)
    {
      if (!dk_set_member (s2, elt))
	DBG_NAME(t_set_push) (DBG_ARGS &un, elt);
    }
  END_DO_SET();
  return un;
}

dk_set_t DBG_NAME(t_set_intersect) (DBG_PARAMS dk_set_t s1, dk_set_t s2)
{
  dk_set_t un = NULL;
  DO_SET (caddr_t, elt, &s1)
    {
      if (dk_set_member (s2, elt))
	DBG_NAME(t_set_push) (DBG_ARGS &un, elt);
    }
  END_DO_SET();
  return un;
}

dk_set_t DBG_NAME(t_set_diff) (DBG_PARAMS dk_set_t s1, dk_set_t s2)
{
  dk_set_t un = NULL;
  DO_SET (caddr_t, elt, &s1)
    {
      if (!dk_set_member (s2, elt))
	DBG_NAME(t_set_push) (DBG_ARGS &un, elt);
    }
  END_DO_SET();
  return un;
}


caddr_t * DBG_NAME(t_list_to_array) (DBG_PARAMS s_node_t * set)
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


caddr_t * DBG_NAME(t_revlist_to_array) (DBG_PARAMS s_node_t * set)
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


int DBG_NAME(t_set_delete) (DBG_PARAMS dk_set_t * set, void *item)
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




dk_set_t DBG_NAME(t_set_copy) (DBG_PARAMS dk_set_t s)
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
mp_check_tree (mem_pool_t *mp, box_t box)
{
  uint32 count;
  dtp_t tag;
  if (!IS_BOX_POINTER (box))
    return;
  mp_alloc_box_assert (mp, (caddr_t)box);
  tag = box_tag (box);
  if (IS_NONLEAF_DTP(tag))
    {
      box_t *obj = (box_t *) box;
      for (count = box_length ((caddr_t)box) / sizeof (caddr_t); count; count--)
	mp_check_tree (mp, *obj++);
    }
}
#endif

caddr_t t_box_vsprintf (size_t buflen_eval, const char *format, va_list tail)
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


caddr_t t_box_sprintf (size_t buflen_eval, const char *format, ...)
{
  va_list tail;
  caddr_t res;
  va_start (tail, format);
  res = t_box_vsprintf (buflen_eval, format, tail);
  va_end (tail);
  return res;
}

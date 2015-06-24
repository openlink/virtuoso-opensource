/*
 *  Dkpool.h
 *
 *  $Id$
 *
 *  Temp memory pool for objects that should be allocated one by one but freed
 *  together.
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
#ifndef __DKPOOL_H
#define __DKPOOL_H

#include <stdio.h>

void mp_free (mem_pool_t * mp);
void mp_free_large (mem_pool_t * mp, void * ptr);
void mp_cache_large (size_t sz, int n);
extern size_t mp_large_in_use;
extern size_t mp_max_large_in_use;
extern size_t mp_large_reserved;
extern size_t mp_max_large_reserved;
extern size_t mp_large_reserve_limit;
extern size_t mp_large_soft_cap;
extern size_t mp_large_hard_cap;
#ifdef VALGRIND
#define LACERATED_POOL
#endif
#ifdef MALLOC_DEBUG
#define LACERATED_POOL
#endif

#define MP_LARGE_SOFT_CK (mp_large_soft_cap && mp_large_in_use > mp_large_soft_cap)

typedef struct mem_block_s mem_block_t;

typedef void mem_pool_size_cap_cbk_t (mem_pool_t *mp, void *cbk_env);

typedef struct mem_pool_size_cap_s {
  mem_pool_size_cap_cbk_t *	cbk;
  size_t			limit;
  size_t			last_cbk_limit;
  void *			cbk_env;
} mem_pool_size_cap_t;

#ifdef LACERATED_POOL
struct mem_pool_s
{
  int 			mp_fill;
  int 			mp_size;
  int 			mp_block_size;
  caddr_t *		mp_allocs;
  size_t 		mp_bytes;
  dk_hash_t		mp_large;
  resource_t **		mp_large_reuse;
  dk_hash_t *		mp_unames;
  dk_set_t 		mp_trash;		/* dk_alloc_box boxes that must be freed with the mp */
  size_t		mp_reserved;
  size_t		mp_max_bytes;
#if defined (DEBUG) || defined (MALLOC_DEBUG)
  const char *		mp_alloc_file;
  int 			mp_alloc_line;
#endif
#if defined (MALLOC_DEBUG) | defined (VALGRIND)
  dk_hash_t *		mp_box_to_dc; /* debug to map a copied box to its owner dc in this mp */
  const char *		mp_list_alloc_file;
  int 			mp_list_alloc_line;
#endif
  mem_pool_size_cap_t	mp_size_cap;
  caddr_t	mp_comment;
  struct TLSF_struct *	mp_tlsf;
};
#else
struct mem_block_s
{
  struct mem_block_s *	mb_next;
  size_t 		mb_fill;
  size_t 		mb_size;
};

struct mem_pool_s
{
  mem_block_t *		mp_first;
  int 			mp_block_size;
  size_t 		mp_bytes;
  size_t		mp_max_bytes;
  size_t		mp_reserved;
  dk_hash_t		mp_large;
  resource_t **		mp_large_reuse;
  dk_hash_t *		mp_unames;
  dk_set_t 		mp_trash;
#if defined (DEBUG) || defined (MALLOC_DEBUG)
  const char *		mp_alloc_file;
  int 			mp_alloc_line;
#endif
  caddr_t	mp_comment;
  mem_pool_size_cap_t	mp_size_cap;
  struct TLSF_struct *	mp_tlsf;
};
#endif

EXE_EXPORT (mem_pool_t *, mem_pool_alloc, (void));
#if defined (DEBUG) || defined (MALLOC_DEBUG)
extern mem_pool_t *dbg_mem_pool_alloc (const char *file, int line);
#define mem_pool_alloc() dbg_mem_pool_alloc (__FILE__, __LINE__)
#endif

EXE_EXPORT (caddr_t, mp_alloc_box, (mem_pool_t * mp, size_t len, dtp_t dtp));
EXE_EXPORT (caddr_t, mp_alloc_box_ni, (mem_pool_t * mp, int len, dtp_t dtp));
EXE_EXPORT (caddr_t, mp_box_string, (mem_pool_t * mp, const char *str));
EXE_EXPORT (caddr_t, mp_box_substr, (mem_pool_t * mp, ccaddr_t str, int n1, int n2));
EXE_EXPORT (caddr_t, mp_box_dv_short_nchars, (mem_pool_t * mp, const char *str, size_t len));
EXE_EXPORT (caddr_t, mp_box_dv_short_concat, (mem_pool_t * mp, ccaddr_t str1, ccaddr_t str2));
EXE_EXPORT (caddr_t, mp_box_dv_short_strconcat, (mem_pool_t * mp, const char *str1, const char *str2));
EXE_EXPORT (caddr_t, mp_box_dv_uname_string, (mem_pool_t * mp, const char *str));
EXE_EXPORT (caddr_t, mp_box_dv_uname_nchars, (mem_pool_t * mp, const char *str, size_t len));
EXE_EXPORT (caddr_t, mp_box_copy, (mem_pool_t * mp, caddr_t box));
EXE_EXPORT (caddr_t, mp_box_copy_tree, (mem_pool_t * mp, caddr_t box));
EXE_EXPORT (caddr_t, mp_full_box_copy_tree, (mem_pool_t * mp, caddr_t box));
EXE_EXPORT (caddr_t, mp_box_num, (mem_pool_t * mp, boxint num));
EXE_EXPORT (caddr_t, mp_box_iri_id, (mem_pool_t * mp, iri_id_t num));
EXE_EXPORT (caddr_t, mp_box_double, (mem_pool_t * mp, double num));
EXE_EXPORT (caddr_t, mp_box_float, (mem_pool_t * mp, float num));
void * mp_large_alloc (mem_pool_t * mp, size_t sz);
void mp_set_tlsf (mem_pool_t * mp, size_t  sz);

#ifdef MALLOC_DEBUG
extern caddr_t dbg_mp_alloc_box (const char *file, int line, mem_pool_t * mp, size_t len, dtp_t dtp);
extern caddr_t dbg_mp_alloc_box_ni (const char *file, int line, mem_pool_t * mp, int len, dtp_t dtp);
extern caddr_t dbg_mp_box_string (const char *file, int line, mem_pool_t * mp, const char *str);
extern caddr_t dbg_mp_box_substr (const char *file, int line, mem_pool_t * mp, ccaddr_t str, int n1, int n2);
extern caddr_t dbg_mp_box_dv_short_nchars (const char *file, int line, mem_pool_t * mp, const char *str, size_t len);
extern caddr_t dbg_mp_box_dv_short_concat (const char *file, int line, mem_pool_t * mp, ccaddr_t str1, ccaddr_t str2);
extern caddr_t dbg_mp_box_dv_short_strconcat (const char *file, int line, mem_pool_t * mp, const char *str1, const char *str2);
extern caddr_t dbg_mp_box_dv_uname_string (const char *file, int line, mem_pool_t * mp, const char *str);
extern caddr_t dbg_mp_box_dv_uname_nchars (const char *file, int line, mem_pool_t * mp, const char *str, size_t len);
extern caddr_t dbg_mp_box_copy (const char *file, int line, mem_pool_t * mp, caddr_t box);
extern caddr_t dbg_mp_box_copy_tree (const char *file, int line, mem_pool_t * mp, caddr_t box);
extern caddr_t dbg_mp_full_box_copy_tree (const char *file, int line, mem_pool_t * mp, caddr_t box);
extern caddr_t dbg_mp_box_num (const char *file, int line, mem_pool_t * mp, boxint num);
extern caddr_t dbg_mp_box_iri_id (const char *file, int line, mem_pool_t * mp, iri_id_t num);
extern caddr_t dbg_mp_box_double (const char *file, int line, mem_pool_t * mp, double num);
extern caddr_t dbg_mp_box_float (const char *file, int line, mem_pool_t * mp, float num);
#ifndef _USRDLL
#ifndef EXPORT_GATE
#define mp_alloc_box(mp,len,dtp) dbg_mp_alloc_box (__FILE__, __LINE__, (mp), (len), (dtp))
#define mp_alloc_box_ni(mp,len,dtp) dbg_mp_alloc_box_ni (__FILE__, __LINE__, (mp), (len), (dtp))
#define mp_box_string(mp, str) dbg_mp_box_string (__FILE__, __LINE__, (mp), (str))
#define mp_box_substr(mp, str, n1, n2) dbg_mp_box_substr (__FILE__, __LINE__, (mp), (str), (n1), (n2))
#define mp_box_dv_short_nchars(mp, str, len) dbg_mp_box_dv_short_nchars (__FILE__, __LINE__, (mp), (str), (len))
#define mp_box_dv_short_concat(mp, str1, str2) dbg_mp_box_dv_short_concat (__FILE__, __LINE__, (mp), (str1), (str2))
#define mp_box_dv_short_strconcat(mp, str1, str2) dbg_mp_box_dv_short_strconcat (__FILE__, __LINE__, (mp), (str1), (str2))
#define mp_box_dv_uname_string(mp, str) dbg_mp_box_dv_uname_string (__FILE__, __LINE__, (mp), (str))
#define mp_box_dv_uname_nchars(mp, str, len) dbg_mp_box_dv_uname_nchars (__FILE__, __LINE__, (mp), (str), (len))
#define mp_box_copy(mp, box) dbg_mp_box_copy (__FILE__, __LINE__, (mp), (box))
#define mp_box_copy_tree(mp, box) dbg_mp_box_copy_tree (__FILE__, __LINE__, (mp), (box))
#define mp_full_box_copy_tree(mp, box) dbg_mp_full_box_copy_tree (__FILE__, __LINE__, (mp), (box))
#define mp_box_num(mp, num) dbg_mp_box_num (__FILE__, __LINE__, (mp), (num))
#define mp_box_iri_id(mp, num) dbg_mp_box_iri_id (__FILE__, __LINE__, (mp), (num))
#define mp_box_double(mp, num) dbg_mp_box_double (__FILE__, __LINE__, (mp), (num))
#define mp_box_float(mp, num) dbg_mp_box_float (__FILE__, __LINE__, (mp), (num))
#endif
#endif
#endif

#ifdef LACERATED_POOL
void mp_alloc_box_assert (mem_pool_t * mp, caddr_t box);
#else
#define mp_alloc_box_assert(mp,box) ;
#endif

caddr_t *mp_list (mem_pool_t * mp, long n, ...);
#define mp_alloc(mp, n) mp_alloc_box (mp, n, DV_CUSTOM)

#define THR_TMP_POOL  ((mem_pool_t *) THREAD_CURRENT_THREAD->thr_tmp_pool)
#define SET_THR_TMP_POOL(v)  (THREAD_CURRENT_THREAD->thr_tmp_pool = (void*) v)

#ifdef DEBUG						   /* Not MALLOC_DEBUG */
#define MP_START() \
  do { \
    mem_pool_t *thread_mem_pool = THR_TMP_POOL; \
    if (thread_mem_pool != NULL) \
      GPF_T1 ("MP reallocated"); \
    SET_THR_TMP_POOL (dbg_mem_pool_alloc (__FILE__, __LINE__)); \
  } while (0)
#else
#define MP_START() \
  do { \
    if (THR_TMP_POOL != NULL) \
      GPF_T1 ("MP reallocated"); \
    SET_THR_TMP_POOL (mem_pool_alloc ()); \
  } while (0)
#endif

#define MP_DONE() \
  do { \
    mp_free (THR_TMP_POOL); \
  SET_THR_TMP_POOL (NULL);	\
    } while (0)

#ifdef _DEBUG
#define mp_box_tag_modify_impl(box,new_tag) \
 do { \
   box_tag_aux((box)) = (new_tag); \
   } while (0)
#else
#define mp_box_tag_modify_impl(box,new_tag) (box_tag_aux((box)) = (new_tag))
#endif

#ifdef MALLOC_DEBUG
#define mp_box_tag_modify(box,new_tag) \
 do { \
   if (DV_UNAME == new_tag) \
     GPF_T1 ("Can't make UNAME by mp_box_tag_modify"); \
   if (DV_UNAME == box_tag_aux(box)) \
     GPF_T1 ("Can't alter UNAME by mp_box_tag_modify"); \
   if (DV_REFERENCE == new_tag) \
     GPF_T1 ("Can't make REFERENCE by mp_box_tag_modify"); \
   if (DV_REFERENCE == box_tag_aux(box)) \
     GPF_T1 ("Can't alter REFERENCE by mp_box_tag_modify"); \
   if (TAG_FREE == new_tag) \
     GPF_T1 ("Can't make TAG_FREE box by mp_box_tag_modify"); \
   if (TAG_FREE == box_tag_aux(box)) \
     GPF_T1 ("Can't alter TAG_FREE by mp_box_tag_modify"); \
   if (TAG_BAD == new_tag) \
     GPF_T1 ("Can't make TAG_BAD box by mp_box_tag_modify"); \
   if (TAG_BAD == box_tag_aux(box)) \
     GPF_T1 ("Can't alter TAG_BAD by mp_box_tag_modify"); \
   mp_box_tag_modify_impl(box,new_tag); \
   } while (0);
#else
#define mp_box_tag_modify(box,new_tag) mp_box_tag_modify_impl(box,new_tag)
#endif



#define dbg_t_alloc_box(len,dtp)		dbg_mp_alloc_box (DBG_ARGS THR_TMP_POOL, (len), (dtp))
#define dbg_t_box_string(str)			dbg_mp_box_string (DBG_ARGS THR_TMP_POOL, (str))
#define dbg_t_box_substr(str,n1,n2)		dbg_mp_box_substr (DBG_ARGS THR_TMP_POOL, (str), (n1), (n2))
#define dbg_t_box_dv_short_nchars(str,len) 	dbg_mp_box_dv_short_nchars (DBG_ARGS THR_TMP_POOL, (str), (len))
#define dbg_t_box_dv_short_concat(str1,str2) 	dbg_mp_box_dv_short_concat (DBG_ARGS THR_TMP_POOL, (str1), (str2))
#define dbg_t_box_dv_short_strconcat(str1,str2)	dbg_mp_box_dv_short_strconcat (DBG_ARGS THR_TMP_POOL, (str1), (str2))
#define dbg_t_box_dv_uname_string(str)		dbg_mp_box_dv_uname_string (DBG_ARGS THR_TMP_POOL, (str))
#define dbg_t_box_dv_uname_nchars(str,len) 	dbg_mp_box_dv_uname_nchars (DBG_ARGS THR_TMP_POOL, (str), (len))
#define dbg_t_box_copy(box)			dbg_mp_box_copy (DBG_ARGS THR_TMP_POOL, (box))
#define dbg_t_box_copy_tree(box)		dbg_mp_box_copy_tree (DBG_ARGS THR_TMP_POOL, (box))
#define dbg_t_full_box_copy_tree(box)		dbg_mp_full_box_copy_tree (DBG_ARGS THR_TMP_POOL, (box))
#define t_alloc_box(len,dtp)			mp_alloc_box (THR_TMP_POOL, (len), (dtp))
#define t_box_string(str)			mp_box_string (THR_TMP_POOL, (str))
#define t_box_substr(str,n1,n2)			mp_box_substr (THR_TMP_POOL, (str), (n1), (n2))
#define t_box_dv_short_nchars(str,len)		mp_box_dv_short_nchars (THR_TMP_POOL, (str), (len))
#define t_box_dv_short_concat(str1,str2)	mp_box_dv_short_concat (THR_TMP_POOL, (str1), (str2))
#define t_box_dv_short_strconcat(str1,str2)	mp_box_dv_short_strconcat (THR_TMP_POOL, (str1), (str2))
#define t_box_dv_uname_string(str)		mp_box_dv_uname_string (THR_TMP_POOL, (str))
#define t_box_dv_uname_nchars(str,len)		mp_box_dv_uname_nchars (THR_TMP_POOL, (str), (len))
#define t_box_copy(box)				mp_box_copy (THR_TMP_POOL, (box))
#define t_box_copy_tree(box)			mp_box_copy_tree (THR_TMP_POOL, (box))
#define t_full_box_copy_tree(box)		mp_full_box_copy_tree (THR_TMP_POOL, (box))

#define t_alloc_list(n) 			((caddr_t *)t_alloc_box ((n) * sizeof (caddr_t), DV_ARRAY_OF_POINTER))
extern caddr_t *t_list_concat_tail (caddr_t list, long n, ...);
extern caddr_t *t_list_concat (caddr_t list1, caddr_t list2);
extern caddr_t *t_list_remove_nth (caddr_t list, int pos);
extern caddr_t *t_list_insert_before_nth (caddr_t list, caddr_t new_item, int pos);
extern caddr_t *t_list_insert_many_before_nth (caddr_t list, caddr_t * new_items, int ins_count, int pos);
caddr_t *t_sc_list (long n, ...);

#define t_NEW_DB_NULL 				t_alloc_box (0, DV_DB_NULL)

#ifdef MALLOC_DEBUG
caddr_t dbg_t_box_num (const char *file, int line, boxint box);
caddr_t dbg_t_box_num_and_zero (const char *file, int line, boxint box);
box_t dbg_t_box_double (const char *file, int line, double d);
box_t dbg_t_box_float (const char *file, int line, float d);
caddr_t dbg_t_box_iri_id (const char *file, int line, int64 n);
#define t_box_num(box) 				dbg_t_box_num (__FILE__, __LINE__, (box))
#define t_box_double(d) 			dbg_t_box_double (__FILE__, __LINE__, (d))
#define t_box_float(d) 				dbg_t_box_float (__FILE__, __LINE__, (d))
#define t_box_iri_id(d) 			dbg_t_box_iri_id (__FILE__, __LINE__, (d))
#define t_box_num_and_zero(box) 		dbg_t_box_num_and_zero (__FILE__, __LINE__, (box))
extern caddr_t *t_list_impl (long n, ...);
typedef caddr_t *(*t_list_impl_ptr_t) (long n, ...);
extern t_list_impl_ptr_t t_list_cock (const char *file, int line);
#define t_list 					(t_list_cock (__FILE__, __LINE__))
#else
caddr_t t_box_num (boxint box);
caddr_t t_box_num_and_zero (boxint box);
box_t t_box_double (double d);
box_t t_box_float (float d);
caddr_t t_box_iri_id (int64 n);
extern caddr_t *t_list (long n, ...);
#endif

#define t_alloc(sz) 				t_alloc_box ((sz), DV_CUSTOM)
#define t_box_num_nonull 			t_box_num_and_zero
#define t_box_dv_short_string 			t_box_string

#define TNEW(dt, v) \
  dt * v = (dt *) t_alloc (sizeof (dt))

#define t_NEW_VARZ(dt, v) \
  TNEW(dt, v); \
  memset (v, 0, sizeof (dt))

#define t_NEW_VAR(dt, v) \
  TNEW(dt, v)

#ifdef MALLOC_DEBUG
void dbg_mp_set_push (const char *file, int line, mem_pool_t * mp, dk_set_t * set, void *elt);
dk_set_t dbg_t_cons (const char *file, int line, void *car, dk_set_t cdr);
void dbg_t_set_push (const char *file, int line, dk_set_t * set, void *elt);
int dbg_t_set_pushnew (const char *file, int line, s_node_t ** set, void *item);
int dbg_t_set_push_new_string (const char *file, int line, s_node_t ** set, char *item);
void *dbg_t_set_pop (const char *file, int line, dk_set_t * set);
dk_set_t dbg_t_set_union (const char *file, int line, dk_set_t s1, dk_set_t s2);
dk_set_t dbg_t_set_intersect (const char *file, int line, dk_set_t s1, dk_set_t s2);
dk_set_t dbg_t_set_diff (const char *file, int line, dk_set_t s1, dk_set_t s2);
caddr_t *dbg_t_list_to_array (const char *file, int line, dk_set_t list);
caddr_t *dbg_t_revlist_to_array (const char *file, int line, dk_set_t list);
int dbg_t_set_delete (const char *file, int line, dk_set_t * set, void *item);
dk_set_t dbg_t_set_copy (const char *file, int line, dk_set_t s);
#define mp_set_push(mp,set,elt)			dbg_mp_set_push (__FILE__, __LINE__, (mp), (set), (elt))
#define t_cons(car,cdr)				dbg_t_cons (__FILE__, __LINE__, (car), (cdr))
#define t_set_push(set,elt)			dbg_t_set_push (__FILE__, __LINE__, (set), (elt))
#define t_set_pushnew(set,item)			dbg_t_set_pushnew (__FILE__, __LINE__, (set), (item))
#define t_set_push_new_string(set,item)		dbg_t_set_push_new_string (__FILE__, __LINE__, (set), (item))
#define t_set_pop(set)				dbg_t_set_pop (__FILE__, __LINE__, (set))
#define t_set_union(s1,s2)			dbg_t_set_union (__FILE__, __LINE__, (s1), (s2))
#define t_set_intersect(s1,s2)			dbg_t_set_intersect (__FILE__, __LINE__, (s1), (s2))
#define t_set_diff(s1,s2)			dbg_t_set_diff (__FILE__, __LINE__, (s1), (s2))
#define t_list_to_array(list)			dbg_t_list_to_array (__FILE__, __LINE__, (list))
#define t_revlist_to_array(list)		dbg_t_revlist_to_array (__FILE__, __LINE__, (list))
#define t_set_delete(set,item)			dbg_t_set_delete (__FILE__, __LINE__, (set), (item))
#define t_set_copy(s)				dbg_t_set_copy (__FILE__, __LINE__, (s))
#else
void mp_set_push (mem_pool_t * mp, dk_set_t * set, void *elt);
dk_set_t t_cons (void *car, dk_set_t cdr);
void t_set_push (dk_set_t * set, void *elt);
int t_set_pushnew (s_node_t ** set, void *item);
int t_set_push_new_string (s_node_t ** set, char *item);
void *t_set_pop (dk_set_t * set);
dk_set_t t_set_union (dk_set_t s1, dk_set_t s2);
dk_set_t t_set_intersect (dk_set_t s1, dk_set_t s2);
dk_set_t t_set_diff (dk_set_t s1, dk_set_t s2);
caddr_t *t_list_to_array (dk_set_t list);
caddr_t *t_revlist_to_array (dk_set_t list);
int t_set_delete (dk_set_t * set, void *item);
dk_set_t t_set_copy (dk_set_t s);
#endif
#define mp_set_nreverse(mp,s) dk_set_nreverse((s))
#define t_set_nreverse(s) dk_set_nreverse((s))
#define t_revlist_to_array_or_null(list)	((NULL != (list)) ? t_revlist_to_array ((list)) : NULL)


#ifdef MALLOC_DEBUG
void mp_check (mem_pool_t * mp);
void mp_check_tree (mem_pool_t * mp, box_t box);
#define t_check_tree(box) 			mp_check_tree (THR_TMP_POOL, (box))
#else
#define mp_check_tree(mp,box)			;
#define t_check_tree(box)			;
#endif

#ifdef _DKSYSTEM_H
caddr_t t_box_vsprintf (size_t buflen_eval, const char *format, va_list tail);
caddr_t t_box_sprintf (size_t buflen_eval, const char *format, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 2, 3)))
#endif
;
#endif

void mp_trash (mem_pool_t * mp, caddr_t box);
#define mp_trash_push(mp,box) dk_set_push (&((mp)->mp_trash), (void *)(box))
#define t_trash_push(box) mp_trash_push(THR_TMP_POOL,box)

extern box_tmp_copy_f box_tmp_copier[256];

#ifdef LACERATED_POOL
#define MP_BYTES(x, mp, len)  			{ (x) = (void *)mp_alloc_box (mp, len, DV_NON_BOX); }
#else
#define MP_BYTES(x, mp, len2) \
  { \
    int __len = ALIGN_8 (len2); \
    mem_block_t * f = mp->mp_first; \
    if (f && f->mb_fill + __len <= f->mb_size) \
      { \
	(x) = (void *)(((char*)f) + f->mb_fill); \
	f->mb_fill += __len; \
      } \
    else \
      (x) = (void *)mp_alloc_box (mp, len2, DV_NON_BOX); \
  }
#endif

#define MP_INT(x, mp, v, tag_word)		\
  { \
    MP_BYTES (x, mp, 16); \
    x = ((char *)x) + 8; \
    *(int64 *)x = v; \
    ((int64*)x)[-1] = tag_word; \
  }


#define MP_DOUBLE(x, mp, v, tag_word)		\
  { \
    MP_BYTES (x, mp, 16); \
    x = ((char *)x) + 8; \
    *(double *)x = v; \
    ((int64*)x)[-1] = tag_word; \
  }


#define MP_FLOAT(x, mp, v, tag_word)		\
  { \
    MP_BYTES (x, mp, 16); \
    x = ((char *)x) + 8; \
    *(float *)x = v; \
    ((int64*)x)[-1] = tag_word; \
  }


typedef struct auto_pool_s
{
  caddr_t 	ap_area;
  int 		ap_size;
  int 		ap_fill;
} auto_pool_t;

#define AUTO_POOL(n) \
  int64  area[n];  \
  auto_pool_t ap; \
  ap.ap_area = (caddr_t) &area;			\
  ap.ap_fill = 0; \
  ap.ap_size = sizeof (area); \

caddr_t ap_box_num (auto_pool_t * ap, int64 i);
caddr_t ap_alloc_box (auto_pool_t * ap, int n, dtp_t tag);
caddr_t *ap_list (auto_pool_t * apool, long n, ...);
caddr_t ap_box_iri_id (auto_pool_t * ap, int64 n);
extern caddr_t *t_list_nc (long n, ...);


#define WITHOUT_TMP_POOL \
  { \
    mem_pool_t * __mp = THR_TMP_POOL; \
    SET_THR_TMP_POOL (NULL);

#define END_WITHOUT_TMP_POOL \
    SET_THR_TMP_POOL (__mp); \
  }

#define NO_TMP_POOL \
  if (THR_TMP_POOL) GPF_T1 ("not supposed to have a tmp pool in effect here");

#ifdef linux
#define  HAVE_SYS_MMAN_H 1
#endif

void mm_cache_init (size_t sz, size_t min, size_t max, int steps, float step);
void* mm_large_alloc (size_t sz);
void mm_free_sized (void* ptr, size_t sz);
size_t mm_next_size (size_t n, int * nth);
size_t mm_cache_trim (size_t target_sz, int age_limit, int old_only);
extern size_t mp_block_size;

#if !defined (NDEBUG) /*&& !defined (MALLOC_DEBUG)*/

#define MP_MAP_CHECK

typedef struct dk_pool_4g {
  unsigned char 	bits[128 * 1024];
} dk_pool_4g_t;

extern dk_pool_4g_t * dk_pool_map[256 * 256];

void mp_check_not_in_pool (int64 ptr);

#define ASSERT_NOT_IN_POOL(ptr)			\
{ \
  int64 __ptr = (int64)ptr; \
  dk_pool_4g_t * map = dk_pool_map[__ptr >> 32]; \
if (map && map->bits[((uint32)__ptr) >> 15] & (1 << (((((uint32)__ptr) >> 12) & 0x7)))) \
  mp_check_not_in_pool (__ptr);						\
}

#else
#define ASSERT_NOT_IN_POOL(ptr)
#endif

int mp_reuse_large (mem_pool_t * mp, void * ptr);
int mp_reserve (mem_pool_t * mp, size_t inc);
void mp_comment (mem_pool_t * mp, char * str1, char * str2);
size_t  mp_block_size_sc (size_t sz);

#endif /* ifdef __DKPOOL_H */

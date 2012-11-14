/*
 *  hashext.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifndef _HASHEXT_H
#define _HASHEXT_H
#include "Dk.h"

/* id_hashed_key_t is an unsigned 31-bit integer.
The bit 32 should always be zero.

Moreover, when the hash is calculated as a sequence of bitwise
operations on an initial seed, all intermediate results should be
unsigned and 32-bits, even if the platform is 64 bit, to have reproducible
errors */
typedef uint32 id_hashed_key_t;
#define ID_HASHED_KEY_MASK 		0xFFFffff
#ifdef DEBUG
#define ID_HASHED_KEY_CHECK(i) \
  do { \
    if ((i) & ~ID_HASHED_KEY_MASK) GPF_T1("invalid hashed value"); \
  } while (0)
#else
#define ID_HASHED_KEY_CHECK(i)
#endif

typedef id_hashed_key_t (*hash_func_t) (caddr_t p_data);
typedef int (*cmp_func_t) (caddr_t d1, caddr_t d2);
typedef int (*cmp_func_with_ctx_t) (caddr_t d1, caddr_t d2, void *ctx);

typedef struct id_hash_s id_hash_t;

typedef void (*id_hash_free_t) (id_hash_t *);

#define ID_HASH_LOCK_REFCOUNT 		0x3FFFFFFF

struct id_hash_s
  {
    int			ht_key_length;		/*!< Number of bytes in key */
    int			ht_data_length;		/*!< Number of bytes in dependent data */
    id_hashed_key_t	ht_buckets;		/*!< Buckets */
    int			ht_bucket_length;	/*!< Number of buckets */
    int			ht_data_inx;
    int			ht_ext_inx;
    char *		ht_array;
    hash_func_t		ht_hash_func;
    cmp_func_t		ht_cmp;
    long		ht_inserts;
    long		ht_deletes;
    long		ht_overflows;		/*!< Number of bucket overflows */
    uint32      	ht_count;
    int         	ht_rehash_threshold;
    int			ht_dict_refctr;		/*!< Number of references to dictionary, if the hastable is used as a box */
    long		ht_dict_version;	/*!< Version of dictionary, to track parallel access */
    size_t 		ht_dict_mem_in_use;	/*!< Approximate size of dictonary in memory. Each stored item adds length of key + lenght of the data + size of hash table entry. That is filled only if \c ht_dict_max_mem_in_use is not zero */
    size_t 		ht_dict_max_entries;	/*!< Maximum number of entries kept in dictonary */
    size_t 		ht_dict_max_mem_in_use;	/*!< Memory size limit to prevent exausting of the physical memory */
    dk_mutex_t *	ht_mutex;		/*!< Optional mutex, esp. popular when this is a dictionary propagated across threads of async queue. The mutex is NOT owned by the hashtable box! */
    id_hash_free_t	ht_free_hook;
#ifdef RH_TRACE
    int64		ht_rem_k;
    char *		ht_rem_file;
    int			ht_rem_line;
#endif
};




typedef struct id_hash_iterator_s
{
  id_hash_t *		hit_hash;
  int 			hit_bucket;
  char *		hit_chilum;
  long 			hit_dict_version;
} id_hash_iterator_t;


/* The structure of the bucket array is this:
   char key [key_length bytes]
   char data [data_len bytes];
   idh_ext_t * overflow;
  data
*/

#define BUCKET(ht,n) \
  (&ht->ht_array[n * ht->ht_bucket_length])

#define BUCKET_OVERFLOW(bucket, ht) \
  * ((char **) (&((char *) bucket)[ht->ht_ext_inx]))

#define BUCKET_IS_EMPTY(bucket, ht) \
  (BUCKET_OVERFLOW (bucket, ht) == (char *) -1L)

/* A copy of this definition is in xmlparser.h */
#ifndef LENMEM_T_DEFINED
#define LENMEM_T_DEFINED
struct lenmem_s
{
  size_t 		lm_length;
  char *		lm_memblock;
};

typedef struct lenmem_s lenmem_t;
#endif

/* Dkhashext.c */

EXE_EXPORT (id_hash_t *, id_hash_allocate, (id_hashed_key_t buckets, int keybytes, int databytes, hash_func_t hf, cmp_func_t cf));
EXE_EXPORT (void, id_hash_set, (id_hash_t * ht, caddr_t key, caddr_t data));
EXE_EXPORT (void, id_hash_set_with_hash_number, (id_hash_t * ht, caddr_t key, caddr_t data, id_hashed_key_t inx));
EXE_EXPORT (caddr_t, id_hash_add_new, (id_hash_t * ht, caddr_t key, caddr_t data));
EXE_EXPORT (caddr_t, box_dv_dict_hashtable, (id_hashed_key_t buckets));
EXE_EXPORT (caddr_t, box_dv_dict_iterator, (caddr_t ht));
EXE_EXPORT (void, id_hash_free, (id_hash_t * hash));
EXE_EXPORT (void, id_hash_clear, (id_hash_t * hash));
EXE_EXPORT (void, id_hash_rehash, (id_hash_t * ht, uint32 new_sz));
EXE_EXPORT (int, id_hash_remove, (id_hash_t * ht, caddr_t key));
EXE_EXPORT (int, id_hash_get_and_remove, (id_hash_t * ht, caddr_t key, caddr_t found_key, caddr_t found_data));
EXE_EXPORT (int, id_hash_remove_rnd, (id_hash_t * ht, int inx, caddr_t key, caddr_t data));
EXE_EXPORT (id_hash_t *, id_str_hash_create, (id_hashed_key_t buckets));
EXE_EXPORT (id_hash_t *, id_strcase_hash_create, (id_hashed_key_t buckets));
EXE_EXPORT (void, id_hash_copy, (id_hash_t * to, id_hash_t * from));
EXE_EXPORT (id_hash_t *, id_tree_hash_create, (id_hashed_key_t buckets));

#ifdef MALLOC_DEBUG
caddr_t dbg_box_dv_dict_hashtable (const char *file, int line, id_hashed_key_t buckets);
caddr_t dbg_box_dv_dict_iterator (const char *file, int line, caddr_t ht);
id_hash_t *dbg_id_hash_allocate (const char *file, int line, id_hashed_key_t buckets, int keybytes, int databytes, hash_func_t hf, cmp_func_t cf);
void dbg_id_hash_free (const char *file, int line, id_hash_t * hash);
void dbg_id_hash_clear (const char *file, int line, id_hash_t * hash);
void dbg_id_hash_set (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t data);
void dbg_id_hash_set_with_hash_number (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t data, id_hashed_key_t inx);
caddr_t dbg_id_hash_add_new (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t data);
void dbg_id_hash_rehash (const char *file, int line, id_hash_t * ht, uint32 new_sz);
int dbg_id_hash_remove (const char *file, int line, id_hash_t * ht, caddr_t key);
int dbg_id_hash_get_and_remove (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t found_key, caddr_t found_data);
id_hash_t *dbg_id_str_hash_create (const char *file, int line, id_hashed_key_t buckets);
int dbg_id_hash_remove_rnd (const char *file, int line, id_hash_t * ht, int inx, caddr_t key, caddr_t data);
id_hash_t *dbg_id_strcase_hash_create (const char *file, int line, id_hashed_key_t buckets);
void dbg_id_hash_copy (const char *file, int line, id_hash_t * to, id_hash_t * from);
id_hash_t *dbg_id_tree_hash_create (const char *file, int line, id_hashed_key_t buckets);
#ifndef _USRDLL
#ifndef EXPORT_GATE
#define box_dv_dict_hashtable(BS)		dbg_box_dv_dict_hashtable (__FILE__, __LINE__, (BS))
#define box_dv_dict_iterator(HT)		dbg_box_dv_dict_iterator (__FILE__, __LINE__, (HT))
#define id_hash_allocate(BS,KB,DB,HF,CF)	dbg_id_hash_allocate (__FILE__, __LINE__, (BS),(KB),(DB),(HF),(CF))
#define id_hash_free(HASH)			dbg_id_hash_free (__FILE__, __LINE__, (HASH))
#define id_hash_clear(HASH)			dbg_id_hash_clear (__FILE__, __LINE__, (HASH))
#define id_hash_set(HT,KEY,DATA)		dbg_id_hash_set (__FILE__, __LINE__, (HT),(KEY),(DATA))
#define id_hash_set_with_hash_number(HT,KEY,DATA, inx)		dbg_id_hash_set_with_hash_number (__FILE__, __LINE__, (HT),(KEY),(DATA), (inx))
#define id_hash_add_new(HT,KEY,DATA)		dbg_id_hash_add_new (__FILE__, __LINE__, (HT),(KEY),(DATA))
#define id_hash_rehash(HT,NS)			dbg_id_hash_rehash (__FILE__, __LINE__, (HT),(NS))
#define id_hash_remove(HT,KEY)			dbg_id_hash_remove (__FILE__, __LINE__, (HT),(KEY))
#define id_hash_get_and_remove(HT,KEY,FKEY,FDATA)	dbg_id_hash_get_and_remove (__FILE__, __LINE__, (HT),(KEY),(FKEY),(FDATA))
#define id_hash_remove_rnd(HT,inx, KEY, data)			dbg_id_hash_remove_rnd (__FILE__, __LINE__, (HT),(inx), (KEY), (data))
#define id_str_hash_create(BS)			dbg_id_str_hash_create (__FILE__, __LINE__, (BS))
#define id_strcase_hash_create(BS)		dbg_id_strcase_hash_create (__FILE__, __LINE__, (BS))
#define id_hash_copy(TO,FROM)			dbg_id_hash_copy (__FILE__, __LINE__, (TO), (FROM))
#define id_tree_hash_create(BS)			dbg_id_tree_hash_create (__FILE__, __LINE__, (BS))
#endif
#endif
#endif

EXE_EXPORT (id_hash_t *, t_id_hash_allocate, (id_hashed_key_t buckets, int keybytes, int databytes, hash_func_t hf, cmp_func_t cf));
EXE_EXPORT (void, t_id_hash_free, (id_hash_t * hash));
EXE_EXPORT (void, t_id_hash_clear, (id_hash_t * hash));
EXE_EXPORT (void, t_id_hash_set, (id_hash_t * ht, caddr_t key, caddr_t data));
EXE_EXPORT (void, t_id_hash_set_with_hash_number, (id_hash_t * ht, caddr_t key, caddr_t data, id_hashed_key_t inx));
EXE_EXPORT (caddr_t, t_id_hash_add_new, (id_hash_t * ht, caddr_t key, caddr_t data));
EXE_EXPORT (void, t_id_hash_rehash, (id_hash_t * ht, uint32 new_sz));
EXE_EXPORT (int, t_id_hash_remove, (id_hash_t * ht, caddr_t key));
EXE_EXPORT (int, t_id_hash_get_and_remove, (id_hash_t * ht, caddr_t key, caddr_t found_key, caddr_t found_data));
EXE_EXPORT (id_hash_t *, t_id_str_hash_create, (id_hashed_key_t buckets));
EXE_EXPORT (id_hash_t *, t_id_strcase_hash_create, (id_hashed_key_t buckets));
EXE_EXPORT (void, t_id_hash_copy, (id_hash_t * to, id_hash_t * from));
EXE_EXPORT (id_hash_t *,t_id_tree_hash_create, (id_hashed_key_t buckets));
#ifdef MALLOC_DEBUG
id_hash_t *dbg_t_id_hash_allocate (const char *file, int line, id_hashed_key_t buckets, int keybytes, int databytes, hash_func_t hf, cmp_func_t cf);
void dbg_t_id_hash_free (const char *file, int line, id_hash_t * hash);
void dbg_t_id_hash_clear (const char *file, int line, id_hash_t * hash);
void dbg_t_id_hash_set (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t data);
void dbg_t_id_hash_set_with_hash_number (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t data, id_hashed_key_t inx);
caddr_t dbg_t_id_hash_add_new (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t data);
void dbg_t_id_hash_rehash (const char *file, int line, id_hash_t * ht, uint32 new_sz);
int dbg_t_id_hash_remove (const char *file, int line, id_hash_t * ht, caddr_t key);
int dbg_t_id_hash_get_and_remove (const char *file, int line, id_hash_t * ht, caddr_t key, caddr_t found_key, caddr_t found_data);
id_hash_t *dbg_t_id_str_hash_create (const char *file, int line, id_hashed_key_t buckets);
id_hash_t *dbg_t_id_strcase_hash_create (const char *file, int line, id_hashed_key_t buckets);
void dbg_t_id_hash_copy (const char *file, int line, id_hash_t * to, id_hash_t * from);
id_hash_t *dbg_t_id_tree_hash_create (const char *file, int line, id_hashed_key_t buckets);
#ifndef _USRDLL
#ifndef EXPORT_GATE
#define t_id_hash_allocate(BS,KB,DB,HF,CF)	dbg_t_id_hash_allocate (__FILE__, __LINE__, (BS),(KB),(DB),(HF),(CF))
#define t_id_hash_free(HASH)			dbg_t_id_hash_free (__FILE__, __LINE__, (HASH))
#define t_id_hash_clear(HASH)			dbg_t_id_hash_clear (__FILE__, __LINE__, (HASH))
#define t_id_hash_set(HT,KEY,DATA)		dbg_t_id_hash_set (__FILE__, __LINE__, (HT),(KEY),(DATA))
#define t_id_hash_set_with_hash_number(HT,KEY,DATA, inx)		dbg_t_id_hash_set_with_hash_number (__FILE__, __LINE__, (HT),(KEY),(DATA),(inx))
#define t_id_hash_add_new(HT,KEY,DATA)		dbg_t_id_hash_add_new (__FILE__, __LINE__, (HT),(KEY),(DATA))
#define t_id_hash_rehash(HT,NS)			dbg_t_id_hash_rehash (__FILE__, __LINE__, (HT),(NS))
#define t_id_hash_remove(HT,KEY)		dbg_t_id_hash_remove (__FILE__, __LINE__, (HT),(KEY))
#define t_id_hash_get_and_remove(HT,KEY,FKEY,FDATA)		dbg_t_id_hash_remove (__FILE__, __LINE__, (HT),(KEY),(FKEY),(FDATA))
#define t_id_str_hash_create(BS)		dbg_t_id_str_hash_create (__FILE__, __LINE__, (BS))
#define t_id_strcase_hash_create(BS)		dbg_t_id_strcase_hash_create (__FILE__, __LINE__, (BS))
#define t_id_hash_copy(TO,FROM)			dbg_t_id_hash_copy (__FILE__, __LINE__, (TO), (FROM))
#define t_id_tree_hash_create(BS)		dbg_t_id_tree_hash_create (__FILE__, __LINE__, (BS))
#endif
#endif
#endif

caddr_t box_dict_hashtable_copy_hook (caddr_t orig_dict);
int box_dict_hashtable_destr_hook (caddr_t dict);
caddr_t box_dict_iterator_copy_hook (caddr_t orig_iter);
int box_dict_iterator_destr_hook (caddr_t iter);

EXE_EXPORT (caddr_t, id_hash_get, (id_hash_t * ht, caddr_t key));
EXE_EXPORT (caddr_t, id_hash_get_with_hash_number, (id_hash_t * ht, caddr_t key, id_hashed_key_t inx));
EXE_EXPORT (caddr_t, id_hash_get_with_ctx, (id_hash_t * ht, caddr_t key, void *ctx));
EXE_EXPORT (caddr_t, id_hash_get_key, (id_hash_t * ht, caddr_t key));
EXE_EXPORT (caddr_t, id_hash_get_key_by_place, (id_hash_t * ht, caddr_t place));
EXE_EXPORT (void, id_hash_iterator, (id_hash_iterator_t * hit, id_hash_t * ht));
EXE_EXPORT (void, id_hash_set_rehash_pct, (id_hash_t * ht, uint32 pct));
EXE_EXPORT (int, hit_next, (id_hash_iterator_t * hit, char **key, char **data));
EXE_EXPORT (id_hashed_key_t, strhash, (char *strp));
id_hashed_key_t strhashcase (char *strp);
EXE_EXPORT (int, strhashcmp, (char *x, char *y));
int strhashcasecmp (char *x, char *y);
id_hashed_key_t lenmemhash (char *strp);	/* For keys like list (2, buffer_length, buffer) */
int lenmemhashcmp (char *x, char *y);	/* For keys like list (2, buffer_length, buffer) */
id_hashed_key_t treehash (char *strp);
int treehashcmp (char *x, char *y);
id_hashed_key_t voidptrhash (char *voidp);	/* For keys like pointer to subtree of XML tree entity */
int voidptrhashcmp (char *x, char *y);	/* For keys like pointer to subtree of XML tree entity */
id_hashed_key_t box_hash (caddr_t box);
EXE_EXPORT (id_hashed_key_t, boxint_hash, (char *x));
EXE_EXPORT (int, boxint_hashcmp, (char *x, char *y));


#define DO_IDHASH(tk, key, td, data, ht) \
{ tk * key##p; \
  td * data##p; \
  id_hash_iterator_t key##hit; \
  id_hash_iterator (&key##hit, ht); \
  while (hit_next (&key##hit, (caddr_t*)&key##p, (caddr_t*)&data##p)) \
    { tk key = *key##p; \
      td data = *data##p;

#define END_DO_IDHASH }}


#endif

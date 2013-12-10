/*
 *  Dkhash.h
 *
 *  $Id$
 *
 *  Hash tables
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

#ifndef _DKHASH_H
#define _DKHASH_H

/*
 * structs hash_elt and dk_hash
 *
 * Implements a trivial hash table that will associate
 * a number with a void * and efficiently retrieve the
 * item given the number
 */

typedef void (*maphash_func) (const void *k, void *data);
typedef void (*maphash3_func) (const void *k, void *data, void *env);

typedef struct hash_elt_s hash_elt_t;

struct hash_elt_s
{
  const void *	key;
  void *	data;
  hash_elt_t *	next;
};

typedef struct
{
  hash_elt_t *	ht_elements;
  uint32 	ht_count;
  uint32 	ht_actual_size;
  uint32 	ht_rehash_threshold;
#ifdef MTX_DEBUG
  dk_mutex_t *	ht_required_mtx;
#endif
#ifdef HT_STATS
  uint32 	ht_max_colls;
  uint32 	ht_stats[30];
  uint32 	ht_ngets;
  uint32 	ht_nsets;
#endif
} dk_hash_t;

#ifdef MTX_DEBUG
#define HT_REQUIRE_MTX(h, m) h->ht_required_mtx = m
#else
#define HT_REQUIRE_MTX(h, m)
#endif

typedef struct
{
  dk_hash_t *	hit_ht;
  hash_elt_t *	hit_elt;
  uint32 	hit_inx;
} dk_hash_iterator_t;


#define HASH_EMPTY		((hash_elt_t *) -1L)
#define HASH_INX(ht,key)	(uint32)((uptrlong)key % ht->ht_actual_size)



#define GETHASH(key_value, ht, result, not_found) \
  { \
    uint32 inx = HASH_INX (ht, (key_value)); \
    hash_elt_t *elt = &ht->ht_elements[inx]; \
    hash_elt_t *next = elt->next; \
    if (next == HASH_EMPTY)\
      goto not_found;\
    if (elt->key == (key_value))	  \
      *(void**)&result = elt->data; \
    else \
      { \
	elt = next; \
	if (!elt) \
	  goto not_found; \
	for (;;) \
	  { \
	    if (elt->key == (key_value))		\
	      { \
		*(void**) &result = elt->data; \
		break; \
	      } \
	    elt = elt->next; \
	    if (!elt) \
	      goto not_found; \
	  } \
      } \
  }


#define DO_HT(kt, k, dt, d, ht) \
  { \
    dk_hash_iterator_t hit; \
    kt k; dt d; \
    dk_hash_iterator (&hit, ht); \
    while (dk_hit_next (&hit, (void**)&k, (void**)&d)) { \



#define END_DO_HT }}


/* Dkhash.c */
extern uint32 hash_nextprime (uint32 n);

#ifdef MALLOC_DEBUG
extern dk_hash_t *dbg_hash_table_allocate (const char *file, int line, uint32 size);
extern void dbg_hash_table_init (const char *file, int line, dk_hash_t * ht, int size);
extern void dbg_hash_table_free (const char *file, int line, dk_hash_t * table);
extern void *dbg_sethash (const char *file, int line, const void *key, dk_hash_t * ht, void *data);
extern int dbg_remhash (const char *file, int line, const void *key, dk_hash_t * ht);
extern void dbg_clrhash (const char *file, int line, dk_hash_t * table);
extern void dbg_dk_rehash (const char *file, int line, dk_hash_t * ht, uint32 new_sz);
#define hash_table_allocate(SIZE)	dbg_hash_table_allocate (__FILE__, __LINE__, (SIZE))
#define hash_table_init(TABLE,SIZE)	dbg_hash_table_init (__FILE__, __LINE__, (TABLE), (SIZE))
#define hash_table_free(TABLE)		dbg_hash_table_free (__FILE__, __LINE__, (TABLE))
#define sethash(KEY,HT,DATA)		dbg_sethash (__FILE__, __LINE__, (KEY), (HT), (DATA))
#define remhash(KEY,HT)			dbg_remhash (__FILE__, __LINE__, (KEY), (HT))
#define clrhash(TABLE)			dbg_clrhash (__FILE__, __LINE__, (TABLE))
#define dk_rehash(HT,NEW_SZ)		dbg_dk_rehash (__FILE__, __LINE__, (HT), (NEW_SZ))
#else
extern dk_hash_t *hash_table_allocate (uint32 size);
extern void hash_table_init (dk_hash_t * ht, int size);
extern void hash_table_free (dk_hash_t * table);
extern void *sethash (const void *key, dk_hash_t * ht, void *data);
extern int remhash (const void *key, dk_hash_t * ht);
extern void clrhash (dk_hash_t * table);
extern void dk_rehash (dk_hash_t * ht, uint32 new_sz);
#endif
void hash_table_destroy (dk_hash_t * ht);

extern void *gethash (const void *key, dk_hash_t * ht);
extern void maphash (maphash_func func, dk_hash_t * table);
extern void maphash3 (maphash3_func func, dk_hash_t * table, void *env);
extern void **hash_list_keys (dk_hash_t * table);
extern void maphash_no_remhash (maphash_func func, dk_hash_t * table);
extern void dk_hash_iterator (dk_hash_iterator_t * hit, dk_hash_t * ht);
extern int dk_hit_next (dk_hash_iterator_t * hit, void **key, void **data);
extern void dk_hash_set_rehash (dk_hash_t * ht, uint32 ov_per_bucket);

typedef int32 (*box_hash_func_t) (caddr_t);
typedef int (*box_hash_cmp_func_t) (ccaddr_t, ccaddr_t);
void dk_dtp_register_hash (dtp_t dtp, box_hash_func_t hf, box_hash_cmp_func_t cmp);
#ifdef DK_ALLOC_BOX_DEBUG						   /* These definitions are here because they need dk_hash_t, otherwise they would be placed into Dkbox.h */
extern void dk_check_tree_iter (box_t box, box_t parent, dk_hash_t * known);
extern void dk_check_domain_of_connectivity_iter (box_t box, box_t parent, dk_hash_t * known);
#endif
#endif /* _DKHASH_H */

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

#ifndef _DKHASH_H
#define _DKHASH_H

/*
 * structs hash_elt and dk_hash
 *
 * Implements a trivial hash table that will associate
 * a number with a void * and efficiently retrieve the
 * item given the number
 */

typedef void	(*maphash_func) (void *k, void *data);

typedef struct hash_elt_s hash_elt_t;

struct hash_elt_s
  {
    void *		key;
    void *		data;
    hash_elt_t *	next;
  };

typedef struct
  {
    hash_elt_t *	ht_elements;
    uint32		ht_count;
    uint32		ht_actual_size;
    uint32		ht_rehash_threshold;
#ifdef HT_STATS
    uint32		ht_max_colls;
    uint32		ht_stats[30];
    uint32		ht_ngets;
    uint32		ht_nsets;
#endif
  } dk_hash_t;

typedef struct
  {
    dk_hash_t *		hit_ht;
    hash_elt_t *	hit_elt;
    uint32		hit_inx;
  } dk_hash_iterator_t;

/* Dkhash.c */
uint32 hash_nextprime (uint32 n);

#ifdef MALLOC_DEBUG
dk_hash_t *dbg_hash_table_allocate (const char *file, int line, uint32 size);
void dbg_hash_table_free (const char *file, int line, dk_hash_t *table);
void *dbg_sethash (const char *file, int line, void *key, dk_hash_t *ht, void *data);
int dbg_remhash (const char *file, int line, void *key, dk_hash_t *ht);
void dbg_clrhash (const char *file, int line, dk_hash_t *table);
void dbg_dk_rehash (const char *file, int line, dk_hash_t *ht, uint32 new_sz);
#define hash_table_allocate(SIZE)	dbg_hash_table_allocate (__FILE__, __LINE__, (SIZE))
#define hash_table_free(TABLE)		dbg_hash_table_free (__FILE__, __LINE__, (TABLE))
#define sethash(KEY,HT,DATA)		dbg_sethash (__FILE__, __LINE__, (KEY), (HT), (DATA))
#define remhash(KEY,HT)			dbg_remhash (__FILE__, __LINE__, (KEY), (HT))
#define clrhash(TABLE)			dbg_clrhash (__FILE__, __LINE__, (TABLE))
#define dk_rehash(HT,NEW_SZ)		dbg_dk_rehash (__FILE__, __LINE__, (HT), (NEW_SZ))
#else
dk_hash_t *hash_table_allocate (uint32 size);
void hash_table_free (dk_hash_t *table);
void *sethash (void *key, dk_hash_t *ht, void *data);
int remhash (void *key, dk_hash_t *ht);
void clrhash (dk_hash_t *table);
void dk_rehash (dk_hash_t *ht, uint32 new_sz);
#endif

void *gethash (void *key, dk_hash_t *ht);
void maphash (maphash_func func, dk_hash_t *table);
void maphash_no_remhash (maphash_func func, dk_hash_t *table);
void dk_hash_iterator (dk_hash_iterator_t *hit, dk_hash_t *ht);
int dk_hit_next (dk_hash_iterator_t *hit, void **key, void **data);
void dk_hash_set_rehash (dk_hash_t *ht, uint32 ov_per_bucket);

#ifdef DEBUG /* These definitions are here because they need dk_hash_t, otherwise they would be placed into Dkbox.h */
extern void dk_check_tree_iter (box_t box, box_t parent, dk_hash_t *known);
extern void dk_check_domain_of_connectivity_iter (box_t box, box_t parent, dk_hash_t *known);
#endif
#endif /* _DKHASH_H */


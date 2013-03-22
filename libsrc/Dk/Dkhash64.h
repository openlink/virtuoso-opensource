/*
 *  Dkhash64.h
 *
 *  $Id$
 *
 *  int64 hashtable for 32 bit platforms
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

#ifndef _DKHASH64_H
#define _DKHASH64_H

#define dk_hash_64_t 			id_hash_t

#define hash_table_allocate_64(sz)  	id_hash_allocate (sz, sizeof (boxint), sizeof (boxint), boxint_hash, boxint_hashcmp)

#define sethash_64(k, ht, v) \
  { \
    int64 kr = k, vr = v; \
    id_hash_set (ht, (caddr_t)&kr, (caddr_t)&vr);	\
  }


typedef struct hash_elt_64_s {
  int64	key;
  int64	data;
  struct hash_elt_64_s *	next;
} hash_elt_64_t;


#define gethash_64(res, k, ht) \
  { \
    int64 * vp, kv = k; \
    vp = (int64*) id_hash_get (ht, (caddr_t)&kv); \
    if (!vp) res = 0; else res = *vp; \
  }


#define GETHASH_64I(result, key_value, ht, not_found)	\
{ \
  union \
  { \
    boxint k; \
    struct \
    { \
      int32 n1; \
      int32 n2; \
    } k32; \
  } n; \
  n.k = key_value; \
  { \
    uint32 inx = (0xfffffff & (n.k32.n1 ^ n.k32.n2)) % ht->ht_buckets; \
    hash_elt_64_t *elt = &((hash_elt_64_t*)ht->ht_array)[inx];	\
    hash_elt_64_t *next = elt->next; \
    if (next == (hash_elt_64_t*)1L)	\
      goto not_found;\
    if (elt->key == (key_value))	  \
      result = elt->data; \
    else \
      { \
	elt = next; \
	if (!elt) \
	  goto not_found; \
	for (;;) \
	  { \
	    if (elt->key == (key_value))		\
	      { \
		result = elt->data; \
		break; \
	      } \
	    elt = elt->next; \
	    if (!elt) \
	      goto not_found; \
	  } \
      } \
  }}



#ifdef RH_TRACE
#define remhash_64(k, ht) \
  { \
    int64 kv = k; \
    ht->ht_rem_k = kv; \
    ht->ht_rem_line = __LINE__; \
    ht->ht_rem_file = __FILE__; \
    id_hash_remove (ht, (caddr_t) &kv); \
  }
#else
#define remhash_64(k, ht) \
  { \
    int64 kv = k; \
    id_hash_remove (ht, (caddr_t) &kv); \
  }
#endif


#ifdef RH_TRACE
#define remhash_64_f(k, ht, flag)			\
  { \
    int64 kv = k; \
    ht->ht_rem_k = kv; \
    ht->ht_rem_line = __LINE__; \
    ht->ht_rem_file = __FILE__; \
    flag = id_hash_remove (ht, (caddr_t) &kv); \
  }
#else
#define remhash_64_f(k, ht, flag)			\
  { \
    int64 kv = k; \
    flag = id_hash_remove (ht, (caddr_t) &kv); \
  }
#endif

#define hash_table_free_64(ht) \
  id_hash_free (ht)

#define dk_hash_64_iterator_t id_hash_iterator_t
#define dk_hash_64_iterator id_hash_iterator
#define dk_hash_64_hit_next hit_next

#endif

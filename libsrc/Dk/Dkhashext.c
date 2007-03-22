/*
 *  Dkhashext.c
 *
 *  $Id$
 *
 *  Hashing
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

/* Aligning failed - not needed since keybytes/databytes are void * (PmN) */
/* But it's inevitable for 64-bit platforms with structures as hash data * (GK) */
#undef NEXT4
#define NEXT4(X)	_RNDUP((X), SIZEOF_VOID_P)


caddr_t
id_hash_get (id_hash_t * ht, caddr_t key)
{
  id_hashed_key_t inx = ht->ht_hash_func (key);
  ID_HASHED_KEY_CHECK(inx);
  inx = (inx & ID_HASHED_KEY_MASK) % ht->ht_buckets;

  if (BUCKET_IS_EMPTY (BUCKET (ht, inx), ht))
    return ((caddr_t) NULL);
  if (ht->ht_cmp (BUCKET (ht, inx), key))
    return (BUCKET (ht, inx) + ht->ht_data_inx);
  else
    {
      char *ext = BUCKET_OVERFLOW (BUCKET (ht, inx), ht);
      while (ext)
	{
	  if (ht->ht_cmp (ext, key))
	    return (ext + ht->ht_data_inx);
	  ext = BUCKET_OVERFLOW (ext, ht);
	}
    }
  return ((caddr_t) NULL);
}


caddr_t
id_hash_get_with_hash_number (id_hash_t * ht, caddr_t key, id_hashed_key_t inx)
{
  ID_HASHED_KEY_CHECK(inx);
  inx = (inx & ID_HASHED_KEY_MASK) % ht->ht_buckets;

  if (BUCKET_IS_EMPTY (BUCKET (ht, inx), ht))
    return ((caddr_t) NULL);
  if (ht->ht_cmp (BUCKET (ht, inx), key))
    return (BUCKET (ht, inx) + ht->ht_data_inx);
  else
    {
      char *ext = BUCKET_OVERFLOW (BUCKET (ht, inx), ht);
      while (ext)
	{
	  if (ht->ht_cmp (ext, key))
	    return (ext + ht->ht_data_inx);
	  ext = BUCKET_OVERFLOW (ext, ht);
	}
    }
  return ((caddr_t) NULL);
}


caddr_t
id_hash_get_with_ctx (id_hash_t * ht, caddr_t key, void *ctx)
{
  id_hashed_key_t inx = ht->ht_hash_func (key);
  cmp_func_with_ctx_t cmp = (cmp_func_with_ctx_t)((void *)ht->ht_cmp);
  ID_HASHED_KEY_CHECK(inx);
  inx = (inx & ID_HASHED_KEY_MASK) % ht->ht_buckets;

  if (BUCKET_IS_EMPTY (BUCKET (ht, inx), ht))
    return ((caddr_t) NULL);
  if (cmp (BUCKET (ht, inx), key, ctx))
    return (BUCKET (ht, inx) + ht->ht_data_inx);
  else
    {
      char *ext = BUCKET_OVERFLOW (BUCKET (ht, inx), ht);
      while (ext)
	{
	  if (ht->ht_cmp (ext, key))
	    return (ext + ht->ht_data_inx);
	  ext = BUCKET_OVERFLOW (ext, ht);
	}
    }
  return ((caddr_t) NULL);
}


caddr_t
id_hash_get_key (id_hash_t * ht, caddr_t key)
{
  caddr_t place = id_hash_get (ht, key);
  if (!place)
    return NULL;
  return (place - ht->ht_key_length);
}


caddr_t
id_hash_get_key_by_place (id_hash_t * ht, caddr_t place)
{
  if (!place)
    return NULL;
  return (place - ht->ht_key_length);
}


void
id_hash_iterator (id_hash_iterator_t * hit, id_hash_t * ht)
{
  hit->hit_hash = ht;
  hit->hit_bucket = 0;
  hit->hit_chilum = NULL;
}


int
hit_next (id_hash_iterator_t * hit, char **key, char **data)
{
  id_hash_t *ht = hit->hit_hash;
  while (((uint32) hit->hit_bucket) < ht->ht_buckets)
    {
      if (hit->hit_chilum)
	{
	  *key = hit->hit_chilum;
	  *data = (*key) + ht->ht_key_length;
	  hit->hit_chilum = BUCKET_OVERFLOW (hit->hit_chilum, ht);
	  if (!hit->hit_chilum)
	    hit->hit_bucket++;
	  return 1;
	}
      else
	{
	  char *ov = BUCKET_OVERFLOW (BUCKET (ht, hit->hit_bucket), ht);

	  if (ov == (char *) -1L)
	    {
	      hit->hit_bucket++;
	      continue;
	    }
	  *key = BUCKET (ht, hit->hit_bucket);
	  *data = (*key) + ht->ht_key_length;
	  if (ov)
	    hit->hit_chilum = ov;
	  else
	    hit->hit_bucket++;
	  return 1;
	}
    }
  return 0;
}


id_hashed_key_t
strhash (char *strp)
{
  char *str = *(char **) strp;
  id_hashed_key_t h;
 NTS_BUFFER_HASH (h, str);
  return (h & ID_HASHED_KEY_MASK);
}


id_hashed_key_t
strhashcase (char *strp)
{
  char *str = *(char **) strp;
  id_hashed_key_t h = 1;
  while (*str)
    {
      h = h + h * (*str | ('A' ^ 'a'));
      str++;
    }
  return (h & ID_HASHED_KEY_MASK);
}


id_hashed_key_t
lenmemhash (char *strp)
{
  lenmem_t *lm = (lenmem_t *) strp;
  size_t len = lm->lm_length;
  id_hashed_key_t h;
  BYTE_BUFFER_HASH (h, lm->lm_memblock, lm->lm_length);
  return (h & ID_HASHED_KEY_MASK);
}


id_hashed_key_t voidptrhash (char *voidp)
{
  voidp = (char *)(((char **)voidp)[0]);
  return (uint32)(((ptrlong)voidp ^ (((ptrlong)voidp) >> 31)) & ID_HASHED_KEY_MASK);
}


int
strhashcmp (char *x, char *y)
{
  return 0 == strcmp(((char **)x)[0], ((char **)y)[0]);
}


int
strhashcasecmp (char *x, char *y)
{
  x = (char *)(((char **)x)[0]);
  y = (char *)(((char **)y)[0]);
  while (x[0])
    {
      if (((int)(x[0]) | ('A' ^ 'a')) ^ ((int)(y[0]) | ('A' ^ 'a')))
	return 0;
      x++;
      y++;
    }
  return ('\0' == y[0]) ? 1 : 0;
}


int
lenmemhashcmp (char *x, char *y)
{
  lenmem_t *lmx = (lenmem_t*) x;
  lenmem_t *lmy = (lenmem_t*) y;
  size_t len = lmx->lm_length;
  if (lmy->lm_length != len)
    return 0;
  return (0 == memcmp(lmx->lm_memblock, lmy->lm_memblock, len));
}


int
voidptrhashcmp (char *x, char *y)
{
  x = (char *)(((char **)x)[0]);
  y = (char *)(((char **)y)[0]);
  return ((y==x) ? 1 : 0);
}


#define ROL(h) ((h << 1) | ((h >> 31) & 1))

box_hash_func_t dtp_hash_func[256];

extern id_hashed_key_t rdf_box_hash (caddr_t box);

id_hashed_key_t
box_hash (caddr_t box)
{
  id_hashed_key_t h;
  dtp_t dtp;
  if (! IS_BOX_POINTER (box))
    return (uint32) ((ptrlong) box) & ID_HASHED_KEY_MASK;
  dtp = box_tag (box);
  if (dtp_hash_func[dtp])
    return ID_HASHED_KEY_MASK & dtp_hash_func[dtp] (box); 
  switch (dtp)
    {
    case DV_LONG_INT:
      return (( *(long *) box) & ID_HASHED_KEY_MASK);
    case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL: case DV_XTREE_HEAD: case DV_XTREE_NODE:
      {
	int inx, len = box_length (box) / sizeof (caddr_t);
	h = 0;
	for (inx = 0; inx < len; inx++)
	  h = ROL (h) ^ box_hash (((caddr_t *) box)[inx]);
	return h & ID_HASHED_KEY_MASK;
      }
    case DV_UNAME:
      DV_UNAME_BOX_HASH (h, box);
      return h & ID_HASHED_KEY_MASK;
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)box;
        id_hashed_key_t h;
        if (rb->rb_ro_id)
          return (rb->rb_ro_id + (rb->rb_ro_id << 16)) & ID_HASHED_KEY_MASK;
        return (rb->rb_lang * 17 + rb->rb_type * 13 + rb->rb_is_complete * 9 + box_hash (rb->rb_box)) & ID_HASHED_KEY_MASK;
      }
    default:
      {
        uint32 len = box_length_inline (box);
        if (len > 0)
	  BYTE_BUFFER_HASH (h, box, box_length_inline (box) - 1);
        else
          h = 0;
	return h & ID_HASHED_KEY_MASK;
      }
    }
}


void dtp_set_cmp (dtp_t dtp, box_hash_cmp_func_t f);


void
dk_dtp_register_hash (dtp_t dtp, box_hash_func_t hf, box_hash_cmp_func_t cmp)
{
  dtp_hash_func[dtp] = hf;
  dtp_set_cmp(dtp, cmp);
}

id_hashed_key_t
treehash (char *strp)
{
  char *str = *(char **) strp;
  return (box_hash (str));
}


int
treehashcmp (char *x, char *y)
{
  return (box_equal ( *((caddr_t *) x), *((caddr_t *) y)));
}


/* Allocator-dependent functions, dk_alloc versions */

#define DBG_HASHEXT_NAME(name) DBG_NAME(name)
#define DBG_HASHEXT_ALLOC(SZ) DK_ALLOC((SZ))
#define DBG_HASHEXT_FREE(BOX,SZ) DK_FREE((BOX),(SZ))

#include "Dkhashext_template.c"


caddr_t DBG_NAME(box_dv_dict_hashtable) (DBG_PARAMS id_hashed_key_t buckets)
{
  id_hash_t *res = (id_hash_t *) DBG_NAME(dk_alloc_box) (DBG_ARGS sizeof(id_hash_t), DV_DICT_HASHTABLE);
  ID_HASH_ALLOCATE_INTERNALS(res, buckets, sizeof (caddr_t), sizeof (caddr_t),
    treehash, treehashcmp );
  res->ht_dict_refctr = 0;
  res->ht_dict_version = 1;
  return (caddr_t) res;
}


caddr_t DBG_NAME(box_dv_dict_iterator) (DBG_PARAMS caddr_t ht)
{
  id_hash_iterator_t *res = (id_hash_iterator_t *) DBG_NAME(dk_alloc_box) (DBG_ARGS sizeof(id_hash_iterator_t), DV_DICT_ITERATOR);
  res->hit_hash = (id_hash_t *)ht;
  res->hit_bucket = 0;
  res->hit_chilum = NULL;
  if (ht)
    {
      res->hit_dict_version = ((id_hash_t *)ht)->ht_dict_version;
      ((id_hash_t *)ht)->ht_dict_refctr += 1;
    }
  else
    res->hit_dict_version = 0;
  return (caddr_t) res;
}


caddr_t box_dict_hashtable_copy_hook (caddr_t orig_dict)
{
#ifdef MALLOC_DEBUG
  char *file = __FILE__;
  int line = __LINE__;
#endif
  id_hashed_key_t buckets;
  id_hash_t *res;
  caddr_t key, val;
  id_hash_iterator_t hit;
  buckets =
    (((id_hash_t *)orig_dict)->ht_inserts -
     ((id_hash_t *)orig_dict)->ht_deletes );
  if (buckets < ((id_hash_t *)orig_dict)->ht_buckets)
    buckets = ((id_hash_t *)orig_dict)->ht_buckets;
  else
    buckets = hash_nextprime (buckets);
  res = (id_hash_t *) dk_alloc_box (sizeof(id_hash_t), DV_DICT_HASHTABLE);
  ID_HASH_ALLOCATE_INTERNALS (res, buckets, sizeof (caddr_t), sizeof (caddr_t),
    treehash, treehashcmp );
  res->ht_dict_refctr = 1;
  res->ht_dict_version = 1;
  id_hash_iterator (&hit, (id_hash_t *)(orig_dict));
  while (hit_next (&hit, &key, &val))
    {
      caddr_t key_copy, val_copy;
      key_copy = box_copy_tree (key);
      val_copy = box_copy_tree (val);
      id_hash_set (res, (caddr_t)(&key_copy), (caddr_t)(&val_copy));
    }
  return (caddr_t)res;
}


int
box_dict_hashtable_destr_hook (caddr_t dict)
{
#ifdef MALLOC_DEBUG
  char *file = __FILE__;
  int line = __LINE__;
#endif
  caddr_t *key, *val;
  id_hash_iterator_t hit;
  id_hash_iterator (&hit, (id_hash_t *)(dict));
  while (hit_next (&hit, (caddr_t *)(&key), (caddr_t *)(&val)))
    {
      dk_free_tree (key[0]);
      dk_free_tree (val[0]);
    }
  id_hash_clear ((id_hash_t *)(dict));
  ID_HASH_FREE_INTERNALS((id_hash_t *)(dict));
  return 0;
}


caddr_t box_dict_iterator_copy_hook (caddr_t orig_iter)
{
  id_hash_iterator_t *org = (id_hash_iterator_t *)orig_iter;
  id_hash_iterator_t *res = (id_hash_iterator_t *)dk_alloc_box (sizeof(id_hash_iterator_t), DV_DICT_ITERATOR);
  res->hit_hash = org->hit_hash;
  res->hit_bucket = org->hit_bucket;
  res->hit_chilum = org->hit_chilum;
  res->hit_dict_version = org->hit_dict_version;
  if (org->hit_hash)
    org->hit_hash->ht_dict_refctr += 1;
  return (caddr_t) res;
}


int
box_dict_iterator_destr_hook (caddr_t iter)
{
  id_hash_iterator_t *hit = (id_hash_iterator_t *)iter;
  if (hit->hit_hash)
    {
      hit->hit_hash->ht_dict_refctr -= 1;
      if (0 == hit->hit_hash->ht_dict_refctr)
	dk_free_box ((caddr_t)(hit->hit_hash));
    }
  return 0;
}


void
id_hash_set_rehash_pct (id_hash_t * ht, uint32 pct)
{
  ht->ht_rehash_threshold = pct;
}


#undef DBG_HASHEXT_NAME
#undef DBG_HASHEXT_ALLOC
#undef DBG_HASHEXT_FREE


/* Allocator-dependent functions, t_alloc versions */

#ifdef MALLOC_DEBUG
#define DBG_HASHEXT_NAME(name) dbg_t_##name
#define DBG_HASHEXT_ALLOC(SZ) dbg_mp_alloc_box (DBG_ARGS THR_TMP_POOL, (SZ), DV_CUSTOM)
#else
#define DBG_HASHEXT_NAME(name) t_##name
#define DBG_HASHEXT_ALLOC(SZ) mp_alloc_box (THR_TMP_POOL, (SZ), DV_CUSTOM)
#endif
#define DBG_HASHEXT_FREE(BOX,SZ)

#include "Dkhashext_template.c"

#undef DBG_HASHEXT_NAME
#undef DBG_HASHEXT_ALLOC
#undef DBG_HASHEXT_FREE

/* Original signatures should exist for exe-exported functions */
#ifdef MALLOC_DEBUG
#undef id_hash_allocate
id_hash_t * id_hash_allocate (id_hashed_key_t buckets, int keybytes, int databytes, hash_func_t hf, cmp_func_t cf)
{
  return dbg_id_hash_allocate (__FILE__, __LINE__, buckets, keybytes, databytes, hf, cf);
}
#undef id_hash_set
void id_hash_set (id_hash_t *ht, caddr_t key, caddr_t data)
{
  dbg_id_hash_set (__FILE__, __LINE__, ht, key, data);
}
#undef id_hash_add_new
caddr_t id_hash_add_new (id_hash_t *ht, caddr_t key, caddr_t data)
{
  return dbg_id_hash_add_new (__FILE__, __LINE__, ht, key, data);
}
#endif

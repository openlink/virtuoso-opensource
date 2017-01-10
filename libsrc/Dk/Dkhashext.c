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
 *  Copyright (C) 1998-2017 OpenLink Software
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

/* Aligning failed - not needed since keybytes/databytes are void * (PmN) */
/* But it's inevitable for 64-bit platforms with structures as hash data * (GK) */
#undef NEXT4
#define NEXT4(X)	_RNDUP((X), SIZEOF_VOID_P)


#define memcpy_8(target, source, len) \
  {if (sizeof (caddr_t) == len) *(caddr_t*)(target) = *(caddr_t*)(source); \
  else memcpy (target, source, len);}

#define memcpy_8c(target, source, len) \
  {if (sizeof (caddr_t) == len) *(caddr_t*)(target) = *(caddr_t*)(source); \
    else if (len) memcpy (target, source, len);}



caddr_t
id_hash_get (id_hash_t * ht, caddr_t key)
{
  id_hashed_key_t inx = ht->ht_hash_func (key);
  ID_HASHED_KEY_CHECK (inx);
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
  ID_HASHED_KEY_CHECK (inx);
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
  cmp_func_with_ctx_t cmp = (cmp_func_with_ctx_t) ((void *) ht->ht_cmp);
  ID_HASHED_KEY_CHECK (inx);
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
  BYTE_BUFFER_HASH (h, lm->lm_memblock, len);
  return (h & ID_HASHED_KEY_MASK);
}


id_hashed_key_t
voidptrhash (char *voidp)
{
  voidp = (char *) (((char **) voidp)[0]);
  return (uint32) (((ptrlong) voidp ^ (((ptrlong) voidp) >> 31)) & ID_HASHED_KEY_MASK);
}


int
strhashcmp (char *x, char *y)
{
  return 0 == strcmp (((char **) x)[0], ((char **) y)[0]);
}


int
strhashcasecmp (char *x, char *y)
{
  x = (char *) (((char **) x)[0]);
  y = (char *) (((char **) y)[0]);
  while (x[0])
    {
      if (((int) (x[0]) | ('A' ^ 'a')) ^ ((int) (y[0]) | ('A' ^ 'a')))
	return 0;
      x++;
      y++;
    }
  return ('\0' == y[0]) ? 1 : 0;
}


int
lenmemhashcmp (char *x, char *y)
{
  lenmem_t *lmx = (lenmem_t *) x;
  lenmem_t *lmy = (lenmem_t *) y;
  size_t len = lmx->lm_length;
  if (lmy->lm_length != len)
    return 0;
  return (0 == memcmp (lmx->lm_memblock, lmy->lm_memblock, len));
}


int
voidptrhashcmp (char *x, char *y)
{
  x = (char *) (((char **) x)[0]);
  y = (char *) (((char **) y)[0]);
  return ((y == x) ? 1 : 0);
}


id_hashed_key_t
boxint_hash (char *x)
{
  union
  {
    boxint k;
    struct
    {
      int32 n1;
      int32 n2;
    } k32;
  } n;
  n.k = *(boxint *) x;
  return 0xfffffff & (n.k32.n1 ^ n.k32.n2);
}


int
boxint_hashcmp (char *x, char *y)
{
  boxint k1 = *(boxint *) x, k2 = *(boxint *) y;
  return k1 == k2 ? 1 : 0;
}

box_hash_func_t dtp_hash_func[256];

extern id_hashed_key_t rdf_box_hash (caddr_t box);

id_hashed_key_t
box_hash (caddr_t box)
{
  id_hashed_key_t h;
  dtp_t dtp;
  if (!IS_BOX_POINTER (box))
    return ((uint32) ((ptrlong) box)) & ID_HASHED_KEY_MASK;
  dtp = box_tag (box);
  if (dtp_hash_func[dtp])
    return ID_HASHED_KEY_MASK & dtp_hash_func[dtp] (box);
  switch (dtp)
    {
    case DV_LONG_INT:
      {
	uint64 i = *(uint64*)box;
	return ((i >> 32) ^ i) & ID_HASHED_KEY_MASK;
      }
    case DV_IRI_ID:
    case DV_IRI_ID_8:
      if (NULL == box)
	return 0;
      return ((*(unsigned int64 *) box) & ID_HASHED_KEY_MASK);

    case DV_ARRAY_OF_POINTER:
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
    case DV_XTREE_HEAD:
    case DV_XTREE_NODE:
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

    default:
      {
	uint32 len = box_length_inline (box);
	if (len > 0)
	  BYTE_BUFFER_HASH (h, box, len - 1); /* was BYTE_BUFFER_HASH2 but it break xslt compare with UNAMEs etc. */
	else
	  h = 0;
	return h & ID_HASHED_KEY_MASK;
      }
    }
}

id_hashed_key_t
box_hash_cut (caddr_t box, int depth)
{
  id_hashed_key_t h;
  dtp_t dtp;
  if (!IS_BOX_POINTER (box))
    return ((uint32) ((ptrlong) box)) & ID_HASHED_KEY_MASK;
  dtp = box_tag (box);
  if (dtp_hash_func[dtp])
    return ID_HASHED_KEY_MASK & dtp_hash_func[dtp] (box);
  switch (dtp)
    {
    case DV_LONG_INT:
      return ((*(boxint *) box) & ID_HASHED_KEY_MASK);
    case DV_IRI_ID:
    case DV_IRI_ID_8:
      if (NULL == box)
        return 0;
      return ((*(unsigned int64 *) box) & ID_HASHED_KEY_MASK);
    case DV_ARRAY_OF_POINTER:
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_XQVAL:
    case DV_XTREE_HEAD:
    case DV_XTREE_NODE:
      {
        int inx, len = box_length (box) / sizeof (caddr_t);
        if (0 >= depth)
          return ((id_hashed_key_t)len * dtp) & ID_HASHED_KEY_MASK;
        h = 0;
        depth--;
        for (inx = 0; inx < len; inx++)
          h = ROL (h) ^ box_hash_cut (((caddr_t *) box)[inx], depth);
        return h & ID_HASHED_KEY_MASK;
      }
    case DV_UNAME:
      DV_UNAME_BOX_HASH (h, box);
      return h & ID_HASHED_KEY_MASK;
    default:
      {
        uint32 len = box_length_inline (box);
        if (len > 0)
          BYTE_BUFFER_HASH (h, box, len - 1);
        else
          h = 0;
        return h & ID_HASHED_KEY_MASK;
      }
    }
}

void dtp_set_cmp (dtp_t dtp, box_hash_cmp_func_t f);
void dtp_set_strong_cmp (dtp_t dtp, box_hash_cmp_func_t f);


void
dk_dtp_register_hash (dtp_t dtp, box_hash_func_t hf, box_hash_cmp_func_t cmp, box_hash_cmp_func_t strong_cmp)
{
  dtp_hash_func[dtp] = hf;
  dtp_set_cmp (dtp, cmp);
  dtp_set_strong_cmp (dtp, strong_cmp);
}


id_hashed_key_t
treehash (char *strp)
{
  char *str = *(char **) strp;
  return (box_hash (str));
}

extern int box_strong_equal (cbox_t b1, cbox_t b2);

int
treehashcmp (char *x, char *y)
{
  return (box_strong_equal (*((caddr_t *) x), *((caddr_t *) y)));
}


/* Allocator-dependent functions, dk_alloc versions */

#define DBG_HASHEXT_NAME(name) DBG_NAME(name)
#define DBG_HASHEXT_ALLOC(SZ) DK_ALLOC((SZ))
#define DBG_HASHEXT_FREE(BOX,SZ) DK_FREE((BOX),(SZ))

#include "Dkhashext_template.c"

caddr_t
DBG_NAME (box_dv_dict_hashtable) (DBG_PARAMS id_hashed_key_t buckets)
{
  id_hash_t *res = (id_hash_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (id_hash_t), DV_DICT_HASHTABLE);
  ID_HASH_ALLOCATE_INTERNALS (res, buckets, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  res->ht_dict_version = 1;
  res->ht_rehash_threshold = 50;
  return (caddr_t) res;
}


caddr_t
DBG_NAME (box_dv_dict_iterator) (DBG_PARAMS caddr_t ht_box)
{
  id_hash_iterator_t *res = (id_hash_iterator_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (id_hash_iterator_t), DV_DICT_ITERATOR);
  id_hash_t *ht = (id_hash_t *) ht_box;
  res->hit_hash = ht;
  res->hit_bucket = -1;
  res->hit_chilum = (char *)(-1);
  if (NULL != ht)
    {
      if (NULL != ht->ht_mutex)
	mutex_enter (ht->ht_mutex);
      res->hit_dict_version = ht->ht_dict_version;
      ht->ht_dict_refctr += 1;
      if (NULL != ht->ht_mutex)
	mutex_leave (ht->ht_mutex);
    }
  else
    res->hit_dict_version = 0;
  return (caddr_t) res;
}


caddr_t
box_dict_hashtable_copy_hook (caddr_t orig)
{
#ifdef MALLOC_DEBUG
  char *file = __FILE__;
  int line = __LINE__;
#endif
  id_hashed_key_t buckets;
  id_hash_t *orig_dict = (id_hash_t *) orig;
  id_hash_t *res;
  caddr_t key, val;
  id_hash_iterator_t hit;
#ifndef NDEBUG
  if (0 >= orig_dict->ht_dict_refctr)
    GPF_T;
#endif
  res = (id_hash_t *) dk_alloc_box (sizeof (id_hash_t), DV_DICT_HASHTABLE);
  if (orig_dict->ht_mutex)
    mutex_enter (orig_dict->ht_mutex);
  buckets = (((id_hash_t *) orig_dict)->ht_inserts - ((id_hash_t *) orig_dict)->ht_deletes);
  if (buckets < orig_dict->ht_buckets)
    buckets = orig_dict->ht_buckets;
  else
    buckets = hash_nextprime (buckets);
  ID_HASH_ALLOCATE_INTERNALS (res, buckets, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  res->ht_dict_refctr = 0;
  res->ht_dict_version = 1;
  res->ht_dict_mem_in_use = orig_dict->ht_dict_mem_in_use;
  res->ht_dict_max_entries = orig_dict->ht_dict_max_entries;
  res->ht_dict_max_mem_in_use = orig_dict->ht_dict_max_mem_in_use;
  id_hash_iterator (&hit, orig_dict);
  while (hit_next (&hit, &key, &val))
    {
      caddr_t key_copy, val_copy;
      key_copy = box_copy_tree (((caddr_t *)key)[0]);
      val_copy = box_copy_tree (((caddr_t *)val)[0]);
      id_hash_set (res, (caddr_t) (&key_copy), (caddr_t) (&val_copy));
    }
  if (orig_dict->ht_mutex)
    {
      res->ht_mutex = mutex_allocate ();
      mutex_leave (orig_dict->ht_mutex);
    }
  return (caddr_t) res;
}


int
box_dict_hashtable_destr_hook (caddr_t dict)
{
#ifdef MALLOC_DEBUG
  char *file = __FILE__;
  int line = __LINE__;
#endif
  caddr_t *key, *val;
  id_hash_t *ht = (id_hash_t *) dict;
  id_hash_iterator_t hit;
#ifndef NDEBUG
  if (0 != ((id_hash_t *) (dict))->ht_dict_refctr)
    GPF_T1 ("Destructor on hashtable with references");
#endif
  if (ht->ht_free_hook)
    ht->ht_free_hook (ht);
  else
    {
      id_hash_iterator (&hit, (id_hash_t *) (dict));
      while (!ht->ht_mp && hit_next (&hit, (caddr_t *) (&key), (caddr_t *) (&val)))
	{
	  dk_free_tree (key[0]);
	  dk_free_tree (val[0]);
	}
    }
  if (ht->ht_mp)
    mp_free ((mem_pool_t*)ht->ht_mp);
  id_hash_clear ((id_hash_t *) (dict));
  ID_HASH_FREE_INTERNALS ((id_hash_t *) (dict));
  return 0;
}


caddr_t
box_dict_iterator_copy_hook (caddr_t orig_iter)
{
  id_hash_iterator_t *org = (id_hash_iterator_t *) orig_iter;
  id_hash_iterator_t *res = (id_hash_iterator_t *) dk_alloc_box (sizeof (id_hash_iterator_t), DV_DICT_ITERATOR);
  res->hit_hash = org->hit_hash;
  res->hit_bucket = org->hit_bucket;
  res->hit_chilum = org->hit_chilum;
  res->hit_dict_version = org->hit_dict_version;
  if (org->hit_hash)
    {
#ifndef NDEBUG
      if (0 >= org->hit_hash->ht_dict_refctr)
	GPF_T;
#endif
      if ((org->hit_hash->ht_mutex) && (ID_HASH_LOCK_REFCOUNT != org->hit_hash->ht_dict_refctr))
	{
	  mutex_enter (org->hit_hash->ht_mutex);
	  org->hit_hash->ht_dict_refctr += 1;
	  mutex_leave (org->hit_hash->ht_mutex);
	}
      else
	org->hit_hash->ht_dict_refctr += 1;
    }
  return (caddr_t) res;
}


int
box_dict_iterator_destr_hook (caddr_t iter)
{
  id_hash_iterator_t *hit = (id_hash_iterator_t *) iter;
  if ((hit->hit_hash) && (ID_HASH_LOCK_REFCOUNT != hit->hit_hash->ht_dict_refctr))
    {
      dk_mutex_t *mtx = hit->hit_hash->ht_mutex;
#ifndef NDEBUG
      if (0 >= hit->hit_hash->ht_dict_refctr)
	GPF_T;
#endif
      if (NULL != mtx)
	{
	  mutex_enter (mtx);
	  hit->hit_hash->ht_dict_refctr -= 1;
	  if (0 == hit->hit_hash->ht_dict_refctr)
	    {
	      dk_free_box ((caddr_t) (hit->hit_hash));
	      mutex_leave (mtx);
	      mutex_free (mtx);
	    }
	  else
	    mutex_leave (mtx);
	}
      else
	{
	  hit->hit_hash->ht_dict_refctr -= 1;
	  if (0 == hit->hit_hash->ht_dict_refctr)
	    dk_free_box ((caddr_t) (hit->hit_hash));
	}
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
#define DBG_HASHEXT_ALLOC(SZ) dbg_mp_alloc_box (DBG_ARGS THR_TMP_POOL, (SZ), DV_NON_BOX)
#else
#define DBG_HASHEXT_NAME(name) t_##name
#define DBG_HASHEXT_ALLOC(SZ) mp_alloc_box_ni (THR_TMP_POOL, (SZ), DV_NON_BOX)
#endif
#define DBG_HASHEXT_FREE(BOX,SZ)
#define FROM_POOL
#include "Dkhashext_template.c"
#undef FROM_POOL
#undef DBG_HASHEXT_NAME
#undef DBG_HASHEXT_ALLOC
#undef DBG_HASHEXT_FREE

/* Original signatures should exist for exe-exported functions */
#ifdef MALLOC_DEBUG
#undef id_hash_allocate
id_hash_t * id_hash_allocate (id_hashed_key_t buckets, int keybytes, int databytes, hash_func_t hf, cmp_func_t cf) { return dbg_id_hash_allocate (__FILE__, __LINE__, buckets, keybytes, databytes, hf, cf); }
#undef id_hash_set
void id_hash_set (id_hash_t * ht, caddr_t key, caddr_t data) { dbg_id_hash_set (__FILE__, __LINE__, ht, key, data); }
#undef id_hash_add_new
caddr_t id_hash_add_new (id_hash_t * ht, caddr_t key, caddr_t data) { return dbg_id_hash_add_new (__FILE__, __LINE__, ht, key, data); }
#undef id_hash_set_with_hash_number
void id_hash_set_with_hash_number (id_hash_t * ht, caddr_t key, caddr_t data, id_hashed_key_t inx) { dbg_id_hash_set_with_hash_number (__FILE__, __LINE__, ht, key, data, inx); }
#undef box_dv_dict_hashtable
caddr_t box_dv_dict_hashtable (id_hashed_key_t buckets) { return dbg_box_dv_dict_hashtable (__FILE__, __LINE__, buckets); }
#undef box_dv_dict_iterator
caddr_t box_dv_dict_iterator (caddr_t ht) { return dbg_box_dv_dict_iterator (__FILE__, __LINE__, ht); }
#undef id_hash_free
void id_hash_free (id_hash_t * hash) { dbg_id_hash_free (__FILE__, __LINE__, hash); }
#undef id_hash_clear
void id_hash_clear (id_hash_t * hash) { dbg_id_hash_clear (__FILE__, __LINE__, hash); }
#undef id_hash_rehash
void id_hash_rehash (id_hash_t * ht, uint32 new_sz) { dbg_id_hash_rehash (__FILE__, __LINE__, ht, new_sz); }
#undef id_hash_remove
int id_hash_remove (id_hash_t * ht, caddr_t key) { return dbg_id_hash_remove (__FILE__, __LINE__, ht, key); }
#undef id_hash_get_and_remove
int id_hash_get_and_remove (id_hash_t * ht, caddr_t key, caddr_t found_key, caddr_t found_data) { return dbg_id_hash_get_and_remove (__FILE__, __LINE__, ht, key, found_key, found_data); }
#undef id_hash_remove_rnd
int id_hash_remove_rnd (id_hash_t * ht, int inx, caddr_t key, caddr_t data) { return dbg_id_hash_remove_rnd (__FILE__, __LINE__, ht, inx, key, data); }
#undef id_str_hash_create
id_hash_t * id_str_hash_create (id_hashed_key_t buckets) { return dbg_id_str_hash_create (__FILE__, __LINE__, buckets); }
#undef id_strcase_hash_create
id_hash_t * id_strcase_hash_create (id_hashed_key_t buckets) { return dbg_id_strcase_hash_create (__FILE__, __LINE__, buckets); }
#undef id_hash_copy
void id_hash_copy (id_hash_t * to, id_hash_t * from) { dbg_id_hash_copy (__FILE__, __LINE__, to, from); }
#undef id_tree_hash_create
id_hash_t * id_tree_hash_create (id_hashed_key_t buckets) { return dbg_id_tree_hash_create (__FILE__, __LINE__, buckets); }
#undef t_id_hash_allocate
id_hash_t * t_id_hash_allocate (id_hashed_key_t buckets, int keybytes, int databytes, hash_func_t hf, cmp_func_t cf) { return dbg_t_id_hash_allocate (__FILE__, __LINE__, buckets, keybytes, databytes, hf, cf); }
#undef t_id_hash_set
void t_id_hash_set (id_hash_t * ht, caddr_t key, caddr_t data) { dbg_t_id_hash_set (__FILE__, __LINE__, ht, key, data); }
#undef t_id_hash_add_new
caddr_t t_id_hash_add_new (id_hash_t * ht, caddr_t key, caddr_t data) { return dbg_t_id_hash_add_new (__FILE__, __LINE__, ht, key, data); }
#undef t_id_hash_set_with_hash_number
void t_id_hash_set_with_hash_number (id_hash_t * ht, caddr_t key, caddr_t data, id_hashed_key_t inx) { dbg_t_id_hash_set_with_hash_number (__FILE__, __LINE__, ht, key, data, inx); }
#undef t_id_hash_free
void t_id_hash_free (id_hash_t * hash) { dbg_t_id_hash_free (__FILE__, __LINE__, hash); }
#undef t_id_hash_clear
void t_id_hash_clear (id_hash_t * hash) { dbg_t_id_hash_clear (__FILE__, __LINE__, hash); }
#undef t_id_hash_rehash
void t_id_hash_rehash (id_hash_t * ht, uint32 new_sz) { dbg_t_id_hash_rehash (__FILE__, __LINE__, ht, new_sz); }
#undef t_id_hash_remove
int t_id_hash_remove (id_hash_t * ht, caddr_t key) { return dbg_t_id_hash_remove (__FILE__, __LINE__, ht, key); }
#undef t_id_hash_get_and_remove
int t_id_hash_get_and_remove (id_hash_t * ht, caddr_t key, caddr_t found_key, caddr_t found_data) { return dbg_t_id_hash_get_and_remove (__FILE__, __LINE__, ht, key, found_key, found_data); }
#undef t_id_hash_remove_rnd
int t_id_hash_remove_rnd (id_hash_t * ht, int inx, caddr_t key, caddr_t data) { return dbg_t_id_hash_remove_rnd (__FILE__, __LINE__, ht, inx, key, data); }
#undef t_id_str_hash_create
id_hash_t * t_id_str_hash_create (id_hashed_key_t buckets) { return dbg_t_id_str_hash_create (__FILE__, __LINE__, buckets); }
#undef t_id_strcase_hash_create
id_hash_t * t_id_strcase_hash_create (id_hashed_key_t buckets) { return dbg_t_id_strcase_hash_create (__FILE__, __LINE__, buckets); }
#undef t_id_hash_copy
void t_id_hash_copy (id_hash_t * to, id_hash_t * from) { dbg_t_id_hash_copy (__FILE__, __LINE__, to, from); }
#undef t_id_tree_hash_create
id_hash_t * t_id_tree_hash_create (id_hashed_key_t buckets) { return dbg_t_id_tree_hash_create (__FILE__, __LINE__, buckets); }
#endif

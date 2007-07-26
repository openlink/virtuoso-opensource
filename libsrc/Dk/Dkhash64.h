



/* int64 ht for 32 bit platforms */

/* #if SIZEOF_VOIDPTR == 4 */

#define dk_hash_64_t id_hash_t

#define hash_table_allocate_64(sz)  id_hash_allocate (sz, sizeof (boxint), sizeof (boxint), boxint_hash, boxint_hashcmp)

#define sethash_64(k, ht, v) \
{ \
int64 kr = k, vr = v; \
id_hash_set (ht, (caddr_t)&kr, (caddr_t)&vr);	\
}

#define gethash_64(res, k, ht) \
{ \
  int64 * vp, kv = k; \
  vp = (int64*) id_hash_get (ht, (caddr_t)&kv); \
  if (!vp) res = 0; else res = *vp; \
}

#define remhash_64(k, ht) \
{ \
  int64 kv = k; \
  id_hash_remove (ht, (caddr_t) &kv); \
}

#define hash_table_free_64(ht) \
  id_hash_free (ht)



  /* #endif */

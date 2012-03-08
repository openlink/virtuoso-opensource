/*
 *  Dkhash.c
 *
 *  $Id$
 *
 *  Hash tables
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
 */

#include "Dk.h"

/* #define MEMDBG */

#ifdef MEMDBG
# define dk_alloc malloc
# define dk_free(b, s) free (b)
#endif

#ifdef MALLOC_DEBUG
#define DK_REHASH(HT,NEW_SZ) dbg_dk_rehash(DBG_ARGS (HT), (NEW_SZ))
#else
#define DK_REHASH dk_rehash
#endif



/* rehash on load factor above .8 */
#define CHECK_REHASH(ht) \
  if ((ht->ht_count * 5) / ht->ht_actual_size > 4) \
    DK_REHASH (ht, ht->ht_actual_size << 1);

#define ht_max_sz 1048573

typedef int PRIME;

static PRIME primetable[] =
{
  /* 2, 3, 5, 7, */ 11, 13, 17, 19,
    /*23, 29, */ 31, /* 37, 41, 43, */ 47, /* 53,
    59, */ 61, /* 67, 71, 73, 79, 83, */ 89, /*
    97, 101, 103, 107, 109, 113, */ 127, /* 131,
    137, 139, 149, 151, 157, 163, 167, 173,
    179, */ 181, /* 191, 193, 197, 199, 211, 223,
    227, 229, 233, 239, 241, */ 251, /* 257, 263,
    269, 271, 277, 281, 283, 293, 307, 311,
    313, 317, 331, 337, 347, 349, 353, 359,
    367, 373, */ 379, /* 383, 389, 397, 401, 409,
    419, 421, 431, 433, 439, 443, 449, 457,
    461, 463, 467, 479, 487, 491, 499, 503, */
    509, /* 521, 523, 541, 547, 557, 563, 569,
    571, 577, 587, 593, 599, 601, 607, 613,
    617, 619, 631, 641, 643, 647, 653, 659,
    661, 673, 677, 683, 691, 701, 709, 719,
    727, 733, 739, 743, 751, 757, */ 761, /* 769,
    773, 787, 797, 809, 811, 821, 823, 827,
    829, 839, 853, 857, 859, 863, 877, 881,
    883, 887, 907, 911, 919, 929, 937, 941,
    947, 953, 967, 971, 977, 983, 991, 997,
    1009, 1013, 1019, */ 1021, /* 1031, 1033, 1039, 1049,
    1051, 1061, 1063, 1069, 1087, 1091, 1093, 1097,
    1103, 1109, 1117, 1123, 1129, 1151, 1153, 1163,
    1171, 1181, 1187, 1193, 1201, 1213, 1217, 1223,
    1229, 1231, 1237, 1249, 1259, 1277, 1279, 1283,
    1289, 1291, 1297, 1301, 1303, 1307, 1319, 1321,
    1327, 1361, 1367, 1373, 1381, 1399, 1409, 1423,
    1427, 1429, 1433, 1439, 1447, 1451, 1453, 1459,
    1471, 1481, 1483, 1487, 1489, 1493, 1499, 1511,
    1523, */ 1531, /* 1543, 1549, 1553, 1559, 1567, 1571,
    1579, 1583, 1597, 1601, 1607, 1609, 1613, 1619,
    1621, 1627, 1637, 1657, 1663, 1667, 1669, 1693,
    1697, 1699, 1709, 1721, 1723, 1733, 1741, 1747,
    1753, 1759, 1777, 1783, 1787, 1789, 1801, 1811,
    1823, 1831, 1847, 1861, 1867, 1871, 1873, 1877,
    1879, 1889, 1901, 1907, 1913, 1931, 1933, 1949,
    1951, 1973, 1979, 1987, 1993, 1997, 1999, 2003,
    2011, 2017, 2027, 2029, */ 2039, /* 2053, 2063, 2069,
    2081, 2083, 2087, 2089, 2099, 2111, 2113, 2129,
    2131, 2137, 2141, 2143, 2153, 2161, 2179, 2203,
    2207, 2213, 2221, 2237, 2239, 2243, 2251, 2267,
    2269, 2273, 2281, 2287, 2293, 2297, 2309, 2311,
    2333, 2339, 2341, 2347, 2351, 2357, 2371, 2377,
    2381, 2383, 2389, 2393, 2399, 2411, 2417, 2423,
    2437, 2441, 2447, 2459, 2467, 2473, 2477, 2503,
    2521, 2531, 2539, 2543, 2549, 2551, 2557, 2579,
    2591, 2593, 2609, 2617, 2621, 2633, 2647, 2657,
    2659, 2663, 2671, 2677, 2683, 2687, 2689, 2693,
    2699, 2707, 2711, 2713, 2719, 2729, 2731, 2741,
    2749, 2753, 2767, 2777, 2789, 2791, 2797, 2801,
    2803, 2819, 2833, 2837, 2843, 2851, 2857, 2861,
    2879, 2887, 2897, 2903, 2909, 2917, 2927, 2939,
    2953, 2957, 2963, 2969, 2971, 2999, 3001, 3011,
    3019, 3023, 3037, 3041, 3049, 3061, */ 3067, /* 3079,
    3083, 3089, 3109, 3119, 3121, 3137, 3163, 3167,
    3169, 3181, 3187, 3191, 3203, 3209, 3217, 3221,
    3229, 3251, 3253, 3257, 3259, 3271, 3299, 3301,
    3307, 3313, 3319, 3323, 3329, 3331, 3343, 3347,
    3359, 3361, 3371, 3373, 3389, 3391, 3407, 3413,
    3433, 3449, 3457, 3461, 3463, 3467, 3469, 3491,
    3499, 3511, 3517, 3527, 3529, 3533, 3539, 3541,
    3547, 3557, 3559, 3571, 3581, 3583, 3593, 3607,
    3613, 3617, 3623, 3631, 3637, 3643, 3659, 3671,
    3673, 3677, 3691, 3697, 3701, 3709, 3719, 3727,
    3733, 3739, 3761, 3767, 3769, 3779, 3793, 3797,
    3803, 3821, 3823, 3833, 3847, 3851, 3853, 3863,
    3877, 3881, 3889, 3907, 3911, 3917, 3919, 3923,
    3929, 3931, 3943, 3947, 3967, 3989, 4001, 4003,
    4007, 4013, 4019, 4021, 4027, 4049, 4051, 4057,
    4073, 4079, 4091, */ 4093, /* 4099, 4111, 4127, 4129,
    4133, 4139, 4153, 4157, 4159, 4177, 4201, 4211,
    4217, 4219, 4229, 4231, 4241, 4243, 4253, 4259,
    4261, 4271, 4273, 4283, 4289, 4297, 4327, 4337,
    4339, 4349, 4357, 4363, 4373, 4391, 4397, 4409,
    4421, 4423, 4441, 4447, 4451, 4457, 4463, 4481,
    4483, 4493, 4507, 4513, 4517, 4519, 4523, 4547,
    4549, 4561, 4567, 4583, 4591, 4597, 4603, 4621,
    4637, 4639, 4643, 4649, 4651, 4657, 4663, 4673,
    4679, 4691, 4703, 4721, 4723, 4729, 4733, 4751,
    4759, 4783, 4787, 4789, 4793, 4799, 4801, 4813,
    4817, 4831, 4861, 4871, 4877, 4889, 4903, 4909,
    4919, 4931, 4933, 4937, 4943, 4951, 4957, 4967,
    4969, 4973, 4987, 4993, 4999, 5003, 5009, 5011,
    5021, 5023, 5039, 5051, 5059, 5077, 5081, 5087,
    5099, 5101, 5107, 5113, 5119, 5147, 5153, 5167,
    5171, 5179, 5189, 5197, 5209, 5227, 5231, 5233,
    5237, 5261, 5273, 5279, 5281, 5297, 5303, 5309,
    5323, 5333, 5347, 5351, 5381, 5387, 5393, 5399,
    5407, 5413, 5417, 5419, 5431, 5437, 5441, 5443,
    5449, 5471, 5477, 5479, 5483, 5501, 5503, 5507,
    5519, 5521, 5527, 5531, 5557, 5563, 5569, 5573,
    5581, 5591, 5623, 5639, 5641, 5647, 5651, 5653,
    5657, 5659, 5669, 5683, 5689, 5693, 5701, 5711,
    5717, 5737, 5741, 5743, 5749, 5779, 5783, 5791,
    5801, 5807, 5813, 5821, 5827, 5839, 5843, 5849,
    5851, 5857, 5861, 5867, 5869, 5879, 5881, 5897,
    5903, 5923, 5927, 5939, 5953, 5981, 5987, 6007,
    6011, 6029, 6037, 6043, 6047, 6053, 6067, 6073,
    6079, 6089, 6091, 6101, 6113, 6121, 6131, 6133, */
    6143, /* 6151, 6163, 6173, 6197, 6199, 6203, 6211,
    6217, 6221, 6229, 6247, 6257, 6263, 6269, 6271,
    6277, 6287, 6299, 6301, 6311, 6317, 6323, 6329,
    6337, 6343, 6353, 6359, 6361, 6367, 6373, 6379,
    6389, 6397, 6421, 6427, 6449, 6451, 6469, 6473,
    6481, 6491, 6521, 6529, 6547, 6551, 6553, 6563,
    6569, 6571, 6577, 6581, 6599, 6607, 6619, 6637,
    6653, 6659, 6661, 6673, 6679, 6689, 6691, 6701,
    6703, 6709, 6719, 6733, 6737, 6761, 6763, 6779,
    6781, 6791, 6793, 6803, 6823, 6827, 6829, 6833,
    6841, 6857, 6863, 6869, 6871, 6883, 6899, 6907,
    6911, 6917, 6947, 6949, 6959, 6961, 6967, 6971,
    6977, 6983, 6991, 6997, 7001, 7013, 7019, 7027,
    7039, 7043, 7057, 7069, 7079, 7103, 7109, 7121,
    7127, 7129, 7151, 7159, 7177, 7187, 7193, 7207,
    7211, 7213, 7219, 7229, 7237, 7243, 7247, 7253,
    7283, 7297, 7307, 7309, 7321, 7331, 7333, 7349,
    7351, 7369, 7393, 7411, 7417, 7433, 7451, 7457,
    7459, 7477, 7481, 7487, 7489, 7499, 7507, 7517,
    7523, 7529, 7537, 7541, 7547, 7549, 7559, 7561,
    7573, 7577, 7583, 7589, 7591, 7603, 7607, 7621,
    7639, 7643, 7649, 7669, 7673, 7681, 7687, 7691,
    7699, 7703, 7717, 7723, 7727, 7741, 7753, 7757,
    7759, 7789, 7793, 7817, 7823, 7829, 7841, 7853,
    7867, 7873, 7877, 7879, 7883, 7901, 7907, 7919,
    7927, 7933, 7937, 7949, 7951, 7963, 7993, 8009,
    8011, 8017, 8039, 8053, 8059, 8069, 8081, 8087,
    8089, 8093, 8101, 8111, 8117, 8123, 8147, 8161,
    8167, 8171, 8179, */ 8191,

    32003, 65521, 131071, 262139, 524287, ht_max_sz
};

/*
 *   Binary search for the next prime that is >= to n
 */
uint32
hash_nextprime (uint32 n)
{
  PRIME *last = &primetable[sizeof (primetable) / sizeof (PRIME) - 1];
  PRIME *base = primetable;

  if (n > ht_max_sz)				 /* last_prime in table */
    return ht_max_sz;

  while (last >= base)
    {
      PRIME *p = &base[(int) ((last - base) >> 1)];
      int res = (int32) n - *p;

      if (res == 0)
	return n;
      if (res < 0)
	last = p - 1;
      else
	base = p + 1;
    }

  return last[1];
}


dk_hash_t *
DBG_NAME (hash_table_allocate) (DBG_PARAMS uint32 size)
{
  dk_hash_t *table = (dk_hash_t *) DK_ALLOC (sizeof (dk_hash_t));
#ifdef MEMDBG
  if (!table)
    GPF_T;
#endif
  memset (table, 0, sizeof (dk_hash_t));
  size = hash_nextprime (size);
  table->ht_elements = (hash_elt_t *) DK_ALLOC (sizeof (hash_elt_t) * size);
#ifdef MEMDBG
  if (!table->ht_elements)
    GPF_T;
#endif
  memset (table->ht_elements, 0xff, sizeof (hash_elt_t) * size);
  table->ht_actual_size = size;
  table->ht_count = 0;
  table->ht_rehash_threshold = 10;
#ifdef HT_STATS
  table->ht_max_colls = 0;
  table->ht_ngets = table->ht_nsets = 0;
  memset (table->ht_stats, 0, sizeof (table->ht_stats));
#endif
  return table;
}


void
DBG_NAME (hash_table_init) (DBG_PARAMS dk_hash_t * table, int size)
{
  memset (table, 0, sizeof (dk_hash_t));
  size = hash_nextprime (size);
  table->ht_elements = (hash_elt_t *) DK_ALLOC (sizeof (hash_elt_t) * size);
#ifdef MEMDBG
  if (!table->ht_elements)
    GPF_T;
#endif
  memset (table->ht_elements, 0xff, sizeof (hash_elt_t) * size);
  table->ht_actual_size = size;
  table->ht_count = 0;
  table->ht_rehash_threshold = 10;
#ifdef HT_STATS
  table->ht_max_colls = 0;
  table->ht_ngets = table->ht_nsets = 0;
  memset (table->ht_stats, 0, sizeof (table->ht_stats));
#endif
}


void
DBG_NAME (hash_table_free) (DBG_PARAMS dk_hash_t * ht)
{
  clrhash (ht);
  DK_FREE (ht->ht_elements, sizeof (hash_elt_t) * ht->ht_actual_size);
  DK_FREE (ht, sizeof (dk_hash_t));
}


void
hash_table_destroy (dk_hash_t * ht)
{
  clrhash (ht);
  dk_free (ht->ht_elements, sizeof (hash_elt_t) * ht->ht_actual_size);
  memset (ht, 0xdd, sizeof (dk_hash_t));
}


#ifdef HT_STATS
void
ht_stats (dk_hash_t * ht)
{
  int i;
  fprintf (stderr, "Tab %p: g=%lu s=%lu [", ht, ht->ht_ngets, ht->ht_nsets);
  for (i = 0; i <= ht->ht_max_colls; i++)
    fprintf (stderr, "%lu ", ht->ht_stats[i]);
  fprintf (stderr, "] count=%lu actual=%lu load=%f\n",
	ht->ht_count, ht->ht_actual_size, (double) ht->ht_count / (double) ht->ht_actual_size);
}
#endif


void *
gethash (const void *key, dk_hash_t * ht)
{
  uint32 inx = HASH_INX (ht, key);
  hash_elt_t *elt = &ht->ht_elements[inx];
  hash_elt_t *next = elt->next;

#ifdef MTX_DEBUG
  if (ht->ht_required_mtx)
    ASSERT_IN_MTX (ht->ht_required_mtx);
#endif
  if (next == HASH_EMPTY)
    return NULL;
#ifdef HT_STATS
  ht->ht_ngets++;
#endif
  if (elt->key == key)
    return elt->data;
  elt = next;
  while (elt)
    {
      if (elt->key == key)
	return elt->data;
      elt = elt->next;
    }
  return NULL;
}


void *
DBG_NAME (sethash) (DBG_PARAMS const void *key, dk_hash_t * ht, void *data)
{
  uint32 inx = HASH_INX (ht, key);
  hash_elt_t *elt = &ht->ht_elements[inx];
  hash_elt_t *next = elt->next;
#ifdef HT_STATS
  uint32 cols;
  ht->ht_nsets++;
#endif

#ifdef MTX_DEBUG
  if (ht->ht_required_mtx)
    ASSERT_IN_MTX (ht->ht_required_mtx);
#endif

  if (HASH_EMPTY == next)
    {
      elt->next = NULL;
      elt->key = key;
      elt->data = data;
      ht->ht_count++;
#ifdef HT_STATS
      ht->ht_stats[0]++;
#endif
      CHECK_REHASH (ht);
      return data;
    }
  if (elt->key == key)
    {
#ifdef HT_STATS
      ht->ht_stats[0]++;
#endif
      elt->data = data;
      return data;
    }
#ifdef HT_STATS
  cols = 1;
#endif
  elt = next;
  while (elt)
    {
      if (elt->key == key)
	{
	  elt->data = data;
#ifdef HT_STATS
	  ht->ht_stats[cols]++;
	  if (cols > ht->ht_max_colls)
	    {
	      ht->ht_max_colls = cols;
	      ht_stats (ht);
	    }
#endif
	  return data;
	}
      elt = elt->next;
#ifdef HT_STATS
      cols++;
#endif
    }
#ifdef HT_STATS
  ht->ht_stats[cols]++;
  if (cols > ht->ht_max_colls)
    {
      ht->ht_max_colls = cols;
      fprintf (stderr, "max colls on table %p now %lu, count=%lu actual=%lu rehash=%lu load=%f\n",
	    ht, cols, ht->ht_count, ht->ht_actual_size, ht->ht_rehash_threshold,
	    (double) ht->ht_count / (double) ht->ht_actual_size);
      ht_stats (ht);
    }
#endif
  {
    hash_elt_t *new_elt = (hash_elt_t *) DK_ALLOC (sizeof (hash_elt_t));
    new_elt->key = key;
    new_elt->data = data;
    new_elt->next = ht->ht_elements[inx].next;
    ht->ht_elements[inx].next = new_elt;
    ht->ht_count++;
    CHECK_REHASH (ht);
  }
  return data;
}


int
DBG_NAME (remhash) (DBG_PARAMS const void *key, dk_hash_t * ht)
{
  uint32 inx = HASH_INX (ht, key);
  hash_elt_t *elt = &ht->ht_elements[inx];
  hash_elt_t *prev = NULL;
  hash_elt_t *next = elt->next;
#ifdef MTX_DEBUG
  if (ht->ht_required_mtx)
    ASSERT_IN_MTX (ht->ht_required_mtx);
#endif
  if (HASH_EMPTY == next)
    return 0;
  if (elt->key == key)
    {
      ht->ht_count--;
      if (NULL == next)
	{
	  elt->next = HASH_EMPTY;
	  return 1;
	}
      else
	{
	  elt->key = next->key;
	  elt->data = next->data;
	  elt->next = next->next;
	  DK_FREE (next, sizeof (hash_elt_t));
	  return 1;
	}
    }
  elt = next;
  while (elt)
    {
      if (elt->key == key)
	{
	  if (prev)
	    prev->next = elt->next;
	  else
	    ht->ht_elements[inx].next = elt->next;
	  DK_FREE ((char *) elt, sizeof (hash_elt_t));
	  ht->ht_count--;
	  return 1;
	}
      else
	{
	  prev = elt;
	  elt = elt->next;
	}
    }
  return 0;
}


void
DBG_NAME (clrhash) (DBG_PARAMS dk_hash_t * table)
{
  uint32 len;
  uint32 inx;
#ifdef MTX_DEBUG
  if (table->ht_required_mtx)
    ASSERT_IN_MTX (table->ht_required_mtx);
#endif
  if (!table->ht_count)
    return;

  len = table->ht_actual_size;
  for (inx = 0; inx < len; inx++)
    {
      hash_elt_t *elt = &table->ht_elements[inx];
      hash_elt_t *next_elt = elt->next;
      if (HASH_EMPTY == next_elt)
	continue;
      elt = next_elt;
      while (elt)
	{
	  next_elt = elt->next;
	  DK_FREE (elt, sizeof (hash_elt_t));
	  elt = next_elt;
	}
      table->ht_elements[inx].next = HASH_EMPTY;
    }
  table->ht_count = 0;
}


#define HQ_CYCLE(k, d, f) \
  __k = (void *) k; \
  __d = (void *) d; \
  if (data_in_store) \
    f (key_store, data_store); \
  else \
    data_in_store = 1; \
  key_store = __k; \
  data_store = __d;

void
maphash (maphash_func func, dk_hash_t * table)
{
  void *key_store = NULL, *data_store = NULL, *__k, *__d;
  int data_in_store = 0;
  uint32 len = table->ht_actual_size;
  uint32 inx;
  uint32 init_count = table->ht_count;
  /* int n_done =0; */
  if (init_count == 0)
    return;
  for (inx = 0; inx < len; inx++)
    {
      hash_elt_t *elt = &table->ht_elements[inx];
      hash_elt_t *next_elt = elt->next;
      if (HASH_EMPTY == next_elt)
	continue;

      HQ_CYCLE (elt->key, elt->data, func);
      /* n_done++;  if (n_done >= init_count) goto all_done; */
      elt = next_elt;
      while (elt)
	{
	  next_elt = elt->next;

	  HQ_CYCLE (elt->key, elt->data, func);
	  /* n_done++; if (n_done >= init_count) goto all_done; */

	  elt = next_elt;
	}
    }

  HQ_CYCLE (0, 0, func);
}


#define HQ_CYCLE3(k, d, f, e) \
  __k = (void *) k; \
  __d = (void *) d; \
  if (data_in_store) \
    f (key_store, data_store, e); \
  else \
    data_in_store = 1; \
  key_store = __k; \
  data_store = __d;

void
maphash3 (maphash3_func func, dk_hash_t * table, void *env)
{
  void *key_store = NULL, *data_store = NULL, *__k, *__d;
  int data_in_store = 0;
  uint32 len = table->ht_actual_size;
  uint32 inx;
  uint32 init_count = table->ht_count;
  /* int n_done =0; */
  if (init_count == 0)
    return;
  for (inx = 0; inx < len; inx++)
    {
      hash_elt_t *elt = &table->ht_elements[inx];
      hash_elt_t *next_elt = elt->next;
      if (HASH_EMPTY == next_elt)
	continue;

      HQ_CYCLE3 (elt->key, elt->data, func, env);
      /* n_done++;  if (n_done >= init_count) goto all_done; */
      elt = next_elt;
      while (elt)
	{
	  next_elt = elt->next;

	  HQ_CYCLE3 (elt->key, elt->data, func, env);
	  /* n_done++; if (n_done >= init_count) goto all_done; */

	  elt = next_elt;
	}
    }

  HQ_CYCLE3 (0, 0, func, env);
}


void
maphash_no_remhash (maphash_func func, dk_hash_t * table)
{

  uint32 len = table->ht_actual_size;
  uint32 inx;
  uint32 init_count = table->ht_count;
  /* int n_done =0; */
  if (init_count == 0)
    return;
  for (inx = 0; inx < len; inx++)
    {
      hash_elt_t *elt = &table->ht_elements[inx];
      hash_elt_t *next_elt = elt->next;
      if (HASH_EMPTY == next_elt)
	continue;

      func (elt->key, elt->data);
      /* n_done++;  if (n_done >= init_count) goto all_done; */
      elt = next_elt;
      while (elt)
	{
	  next_elt = elt->next;

	  func (elt->key, elt->data);
	  /* n_done++; if (n_done >= init_count) goto all_done; */

	  elt = next_elt;
	}
    }
}


void
dk_hash_iterator (dk_hash_iterator_t * hit, dk_hash_t * ht)
{
  hit->hit_inx = 0;
  hit->hit_elt = NULL;
  hit->hit_ht = ht;
}


int
dk_hit_next (dk_hash_iterator_t * hit, void **key, void **data)
{
  hash_elt_t *elt = hit->hit_elt;

#ifdef MTX_DEBUG
  if (hit->hit_ht->ht_required_mtx)
    ASSERT_IN_MTX (hit->hit_ht->ht_required_mtx);
#endif

start:
  if (elt)
    {
      *key = (void *) elt->key;
      *data = elt->data;
      hit->hit_elt = elt->next;
      return 1;
    }
  if (!hit->hit_ht->ht_count)
    return 0;
  for (;;)
    {
      if (hit->hit_inx >= hit->hit_ht->ht_actual_size)
	return 0;
      elt = &hit->hit_ht->ht_elements[hit->hit_inx];
      hit->hit_inx++;
      if (elt->next != HASH_EMPTY)
	goto start;
    }
}


void
DBG_NAME (dk_rehash) (DBG_PARAMS dk_hash_t * ht, uint32 new_sz)
{
  dk_hash_t new_ht;
  uint32 oinx;
  uint32 old_sz;
#ifdef HT_STATS
  uint32 cols;
#endif

  new_sz = hash_nextprime (new_sz);
  if (ht->ht_actual_size >= ht_max_sz)
    {
#ifdef HT_STATS
      fprintf (stderr, "*** HASH TABLE %p FULL ***\n", ht);
#endif
      return;
    }
#ifdef HT_STATS
  fprintf (stderr, "*** HASH TABLE %p REHASH TO %lu\n", ht, new_sz);
#endif

  old_sz = ht->ht_actual_size;
  memset (&new_ht, 0, sizeof (new_ht));
  new_ht.ht_rehash_threshold = ht->ht_rehash_threshold;
  new_ht.ht_actual_size = new_sz;
  new_ht.ht_elements = (hash_elt_t *) DK_ALLOC (sizeof (hash_elt_t) * new_sz);
  memset (new_ht.ht_elements, 0xff, sizeof (hash_elt_t) * new_sz);
#ifdef MTX_DEBUG
  new_ht.ht_required_mtx = ht->ht_required_mtx;
#endif
#ifdef HT_STATS
  memcpy (new_ht.ht_stats, ht->ht_stats, sizeof (ht->ht_stats));
  new_ht.ht_max_colls = 0;
  new_ht.ht_ngets = ht->ht_ngets;
  new_ht.ht_nsets = ht->ht_nsets;
#endif
  for (oinx = 0; oinx < ht->ht_actual_size; oinx++)
    {
      hash_elt_t *elt = &ht->ht_elements[oinx];
      if (elt->next == HASH_EMPTY)
	continue;
      DBG_NAME (sethash) (DBG_ARGS elt->key, &new_ht, elt->data);
      elt = elt->next;
      while (elt)
	{
	  hash_elt_t *next_elt = elt->next;
	  uint32 new_inx = HASH_INX ((&new_ht), elt->key);
	  hash_elt_t *nelt = &new_ht.ht_elements[new_inx];
	  if (nelt->next == HASH_EMPTY)
	    {
	      nelt->key = elt->key;
	      nelt->data = elt->data;
	      nelt->next = NULL;
	      DK_FREE (elt, sizeof (hash_elt_t));
	    }
	  else
	    {
	      elt->next = nelt->next;
	      nelt->next = elt;
	    }
	  elt = next_elt;
	}
    }
  new_ht.ht_count = ht->ht_count;
  DK_FREE (ht->ht_elements, sizeof (hash_elt_t) * old_sz);
  memcpy (ht, &new_ht, sizeof (dk_hash_t));
#ifdef HT_STATS
  ht_stats (ht);
#endif
}


void
dk_hash_set_rehash (dk_hash_t * ht, uint32 ov_per_bucket)
{
  ht->ht_rehash_threshold = ov_per_bucket;
}

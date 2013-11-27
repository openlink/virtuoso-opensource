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
  3, 5,7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 47, 53
, 59, 67, 71, 79, 83, 89, 97, 103, 109, 127
, 137, 149, 157, 167, 179, 191, 211, 223, 239, 251
, 269, 283, 307, 331, 349, 367, 389, 409, 431, 457
, 487, 521, 557, 587, 617, 653, 691, 727, 769, 809
, 853, 907, 953, 1009, 1061, 1117, 1181, 1249, 1319, 1399
, 1471, 1549, 1627, 1709, 1801, 1901, 1997, 2099, 2207, 2333
, 2459, 2591, 2729, 2879, 3023, 3181, 3343, 3511, 3691, 3877
, 4073, 4283, 4507, 4733, 4973, 5227, 5501, 5779, 6073, 6379
, 6701, 7039, 7393, 7789, 8179, 8597, 9029, 9491, 9967, 10477
, 11003, 11579, 12161, 12781, 13421, 14107, 14813, 15559, 16339, 17159
, 18041, 18947, 19913, 20921, 21977, 23081, 24239, 25453, 26729, 28069
, 29473, 30949, 32497, 34123, 35831, 37633, 39521, 41507, 43591, 45779
, 48073, 50497, 53047, 55711, 58511, 61441, 64553, 67783, 71191, 74759
, 78497, 82457, 86587, 90917, 95467, 100267, 105319, 110587, 116131, 121949
, 128047, 134471, 141199, 148279, 155693, 163481, 171659, 180247, 189271, 198761
, 208721, 219169, 230137, 241651, 253741, 266447, 279779, 293773, 308467, 323899
, 340103, 357109, 374977, 393727, 413417, 434107, 455827, 478627, 502591, 527729
, 554117, 581843, 610957, 641513, 673609, 707293, 742663, 779797, 818813, 859783
, 902777, 947917, 995327, 1045111, 1097377, 1152287, 1209931, 1270429, 1333963, 1400669
, 1470709, 1544311, 1621537, 1702627, 1787783, 1877177, 1971049
, 13, 17, 19, 23, 29, 31, 37, 41, 47, 53
, 59, 67, 71, 79, 83, 89, 97, 103, 109, 127
, 137, 149, 157, 167, 179, 191, 211, 223, 239, 251
, 269, 283, 307, 331, 349, 367, 389, 409, 431, 457
, 487, 521, 557, 587, 617, 653, 691, 727, 769, 809
, 853, 907, 953, 1009, 1061, 1117, 1181, 1249, 1319, 1399
, 1471, 1549, 1627, 1709, 1801, 1901, 1997, 2099, 2207, 2333
, 2459, 2591, 2729, 2879, 3023, 3181, 3343, 3511, 3691, 3877
, 4073, 4283, 4507, 4733, 4973, 5227, 5501, 5779, 6073, 6379
, 6701, 7039, 7393, 7789, 8179, 8597, 9029, 9491, 9967, 10477
, 11003, 11579, 12161, 12781, 13421, 14107, 14813, 15559, 16339, 17159
, 18041, 18947, 19913, 20921, 21977, 23081, 24239, 25453, 26729, 28069
, 29473, 30949, 32497, 34123, 35831, 37633, 39521, 41507, 43591, 45779
, 48073, 50497, 53047, 55711, 58511, 61441, 64553, 67783, 71191, 74759
, 78497, 82457, 86587, 90917, 95467, 100267, 105319, 110587, 116131, 121949
, 128047, 134471, 141199, 148279, 155693, 163481, 171659, 180247, 189271, 198761
, 208721, 219169, 230137, 241651, 253741, 266447, 279779, 293773, 308467, 323899
, 340103, 357109, 374977, 393727, 413417, 434107, 455827, 478627, 502591, 527729
, 554117, 581843, 610957, 641513, 673609, 707293, 742663, 779797, 818813, 859783
, 902777, 947917, 995327, 1045111, 1097377, 1152287, 1209931, 1270429, 1333963, 1400669
, 1470709, 1544311, 1621537, 1702627, 1787783, 1877177, 1971049
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
      elt->data = data;
      elt->key = key;
      elt->next = NULL;
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
    hash_elt_t *new_elt = (hash_elt_t *) ht_alloc (ht, sizeof (hash_elt_t));
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

#define HQ_CYCLE_L(k, d) \
  __k = (void *) k; \
  __d = (void *) d; \
  if (data_in_store) \
    res[ctr++] = key_store; \
  else \
    data_in_store = 1; \
  key_store = __k; \
  data_store = __d;

void **hash_list_keys (dk_hash_t * table)
{
  void **res = (void **)dk_alloc_box (sizeof (void *) * table->ht_count, DV_LONG_INT);
  int ctr = 0;
  void *key_store = NULL, *data_store = NULL, *__k, *__d;
  int data_in_store = 0;
  uint32 len = table->ht_actual_size;
  uint32 inx;
  uint32 init_count = table->ht_count;
  /* int n_done =0; */
  if (init_count == 0)
    return res;
  for (inx = 0; inx < len; inx++)
    {
      hash_elt_t *elt = &table->ht_elements[inx];
      hash_elt_t *next_elt = elt->next;
      if (HASH_EMPTY == next_elt)
	continue;
      HQ_CYCLE_L (elt->key, elt->data);
      /* n_done++;  if (n_done >= init_count) goto all_done; */
      elt = next_elt;
      while (elt)
	{
	  next_elt = elt->next;
	  HQ_CYCLE_L (elt->key, elt->data);
	  /* n_done++; if (n_done >= init_count) goto all_done; */
	  elt = next_elt;
	}
    }
  HQ_CYCLE_L (0, 0);
  return res;
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
  new_ht.ht_elements = (hash_elt_t *) ht_alloc (ht, sizeof (hash_elt_t) * new_sz);
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

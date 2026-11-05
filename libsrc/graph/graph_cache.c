/*
 *  graph_cache.c
 *
 *  Thread-safe graph caching implementation
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
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

#include "graph_cache.h"
#include "graph_internal.h"
#include "graph_quad.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "Dk.h"

/* Bounded wait: a loader that dies without publishing must not park every
 * other caller forever, and a graph load can outlive any query timeout. */
#define GCACHE_WAIT_MS          250

/* The cache uses Dk/Thread primitives, so its mutexes show up in
 * MTX_DEBUG and mutex statistics like the rest of the server's. */
typedef dk_mutex_t gcache_mutex_t;
/* A condition for one mutex: WAITERS and PENDING (counts handed out by a
 * broadcast and not yet taken) are only touched with that mutex held. */
typedef struct
{
  semaphore_t *sem;
  int waiters;
  int pending;
} gcache_cond_t;
#define GCACHE_MUTEX_INIT(m)    dk_mutex_init(&(m), MUTEX_TYPE_SHORT)
#define GCACHE_MUTEX_DESTROY(m) dk_mutex_destroy(&(m))
#define GCACHE_MUTEX_LOCK(m)    mutex_enter(&(m))
#define GCACHE_MUTEX_UNLOCK(m)  mutex_leave(&(m))
#define GCACHE_COND_INIT(c)     ((c).sem = semaphore_allocate(0), (c).waiters = (c).pending = 0)
#define GCACHE_COND_DESTROY(c)  semaphore_free((c).sem)
static void
gcache_cond_wait_ms (gcache_cond_t *c, dk_mutex_t *m, int ms)
{
  int entered;
  c->waiters++;
  mutex_leave (m);
  entered = semaphore_enter_timed (c->sem, ms);
  mutex_enter (m);
  c->waiters--;
  if (entered && c->pending > 0)
    c->pending--;
}

/* A count left behind by a waiter that timed out only costs the next waiter
 * one extra look at the entry it waits for. */
static void
gcache_cond_broadcast (gcache_cond_t *c)
{
  for (; c->pending < c->waiters; c->pending++)
    semaphore_leave (c->sem);
}

#define GCACHE_COND_WAIT(c,m)   gcache_cond_wait_ms(&(c), &(m), GCACHE_WAIT_MS)
#define GCACHE_COND_BROADCAST(c) gcache_cond_broadcast(&(c))

/* ============================================================================
 * GLOBAL CACHE STATE
 * ============================================================================ */

static struct
{
  gcache_entry_t entries[GCACHE_MAX_ENTRIES];
  gcache_mutex_t mutex;
  gcache_cond_t load_cond;
  gcache_stats_t stats;
  uint32_t ttl_seconds;
  uint32_t max_entries;
  uint64_t max_bytes;
  uint64_t reaped_generation;	/* s_gcache_generation when stale entries were last reclaimed */
  /* Monotonic under the cache mutex; stamps result slots so the least
   * recently used one can be identified for reuse. */
  uint64_t result_clock;
  bool initialized;
} g_cache = { 0 };

/* Outside g_cache because gcache_init() clears that, and because commits
 * bump it whether or not anything is cached: the host's weight table is
 * stamped with it too.  Bumped inside lt_commit() under the transaction
 * mutex, so it is an atomic and never takes the cache mutex. */
#ifndef GRAPH_OS_WINDOWS
static uint64_t s_gcache_generation = 0;
#define GCACHE_GEN_LOAD()  __atomic_load_n (&s_gcache_generation, __ATOMIC_SEQ_CST)
#define GCACHE_GEN_BUMP()  ((void) __atomic_add_fetch (&s_gcache_generation, 1, __ATOMIC_SEQ_CST))
#define GCACHE_INT_LOAD(x) __atomic_load_n (&(x), __ATOMIC_SEQ_CST)
#else
static volatile LONG64 s_gcache_generation = 0;
#define GCACHE_GEN_LOAD()  ((uint64_t) InterlockedCompareExchange64 (&s_gcache_generation, 0, 0))
#define GCACHE_GEN_BUMP()  ((void) InterlockedIncrement64 (&s_gcache_generation))
#define GCACHE_INT_LOAD(x) (*(volatile int *) &(x))
#endif

/* Per-graph invalidations asked for by commits, applied by the next cache
 * call under the cache mutex.  This mutex is a leaf held for O(1) work, the
 * only lock a commit takes here. */
#define GCACHE_PENDING_MAX 64
static struct
{
  gcache_mutex_t mutex;
  uint64_t ids[GCACHE_PENDING_MAX];
  int n;
  bool overflow;
  bool initialized;
} s_pend;

/* Resources taken off entries under the cache mutex and freed after it is
 * released, so a large snapshot is never torn down inside the mutex that
 * every graph call (and, before, every commit) waits on. */
typedef struct gcache_reclaim_item_s
{
  quad_store_t *store;
  graph_snapshot_t *snapshot;
  void *data[GCACHE_MAX_RESULTS];
  size_t data_size[GCACHE_MAX_RESULTS];
} gcache_reclaim_item_t;

typedef struct gcache_reclaim_s
{
  int n;
  gcache_reclaim_item_t *items;	/* GCACHE_MAX_ENTRIES, allocated on first use */
} gcache_reclaim_t;

/* How the host is told.  A callback rather than a direct call, for the
 * same reason the parallel executor is one: this library builds and runs
 * without Virtuoso, and must not reach into its transaction layer. */
static void (*s_host_live_fn) (int) = NULL;

void
gcache_set_host_live_fn (void (*fn) (int))
{
  s_host_live_fn = fn;
}

static void
gcache_host_set_live (int live)
{
  if (s_host_live_fn)
    s_host_live_fn (live);
}

/* Tell the host whether this cache holds anything.  Call with the cache
 * mutex held, and pass the answer rather than letting the host ask for it:
 * the host's own callback cannot re-enter this mutex.
 *
 * "Reserved but still loading" counts, and has to: the loader has not read
 * a row yet, so a write committing from here on is one the finished entry
 * must not be allowed to look newer than.
 *
 * This is only half the question.  The host has cached state of its own
 * that is keyed on the same generation counter -- a shared weight table
 * outlives the snapshot it was built beside -- so the host ORs this with
 * what it holds.  Reporting only the entry count here would let the gate
 * close over a live weight table and serve weights read before a write. */
static void
gcache_update_live_locked (void)
{
  uint32_t live = g_cache.stats.current_entries;
  if (!live)
    {
      for (uint32_t i = 0; i < g_cache.max_entries; i++)
	if (g_cache.entries[i].loading)
	  {
	    live = 1;
	    break;
	  }
    }
  gcache_host_set_live (live ? 1 : 0);
}

/* ============================================================================
 * INTERNAL HELPERS
 * ============================================================================ */

/* The TTL is an idle timeout, and it has to be, because it was not.
 *
 * expires_at used to be set once, when the entry was built, and never
 * moved.  An entry was therefore dropped exactly [Graph] CacheTTL seconds
 * after it was materialised however hard it was being used -- including
 * in the middle of one statement.  At 633,432 vertices a single-source
 * weighted sweep hits the same entry 633,432 times over about a minute;
 * when the 300-second mark fell inside that statement the entry went, the
 * next row took the miss path, and the statement stopped to reload
 * 34,185,747 edges and rebuild the weight structures -- 20 seconds,
 * sometimes twice.  Measured: the same sweep was 1,454 ms on a young
 * entry and 47,367 / 48,083 / 64,106 ms once the entry was old enough for
 * the boundary to land inside it, and a stack sample through the slow one
 * showed vgraph_load_from_table running underneath the SELECT.  That is
 * the whole of why a published single-source figure ranged over 47 to 78
 * seconds for a traversal that costs about 2.
 *
 * So every hit extends the expiry.  An entry in continuous use never
 * expires, which is the only sensible reading of a cache TTL, and an idle
 * one still goes after the configured time.  Nothing else changes: an
 * entry from an older generation is still stale here regardless of when it
 * was touched, which is what keeps a write visible. */
static gcache_entry_t *
find_entry_locked (const gcache_key_t *key)
{
  for (uint32_t i = 0; i < g_cache.max_entries; i++)
    {
      gcache_entry_t *e = &g_cache.entries[i];
      if ((e->valid || e->loading) && !e->evicting && gcache_key_equals (&e->key, key))
	{
	  /* A valid entry from an older generation is stale: RDF_QUAD
	   * was modified since it was materialised.  Treat as miss. */
	  if (e->valid && e->generation != GCACHE_GEN_LOAD ())
	    continue;
	  return e;
	}
    }
  return NULL;
}

static gcache_entry_t *
find_free_slot_locked (void)
{
  time_t now = time (NULL);
  gcache_entry_t *oldest = NULL;
  time_t oldest_access = 0;

  for (uint32_t i = 0; i < g_cache.max_entries; i++)
    {
      gcache_entry_t *e = &g_cache.entries[i];

      /* Empty slot */
      if (!e->valid && !e->loading)
	return e;

      /* Never take a slot another thread has reserved and is still
       * loading: it was memset to zero on reservation, so its expires_at
       * is 0 and its ref_count is 0, and it would otherwise look like the
       * most attractive victim here. */
      if (e->loading)
	continue;

      /* Expired and unreferenced */
      if (e->expires_at < now && e->ref_count == 0)
	{
	  return e;
	}

      /* Track oldest for LRU eviction */
      if (e->ref_count == 0 && (oldest == NULL || e->last_access < oldest_access))
	{
	  oldest = e;
	  oldest_access = e->last_access;
	}
    }

  return oldest;		/* May be NULL if all entries are referenced */
}

static void
free_entry_resources (gcache_entry_t *e)
{
  if (!e)
    return;

  /* Free any cached algorithm results.
   *
   * No result reference can be outstanding here.  Every caller of this
   * function has already established that the entry's own ref_count is
   * zero -- an entry with live handles is marked evicting instead and
   * freed by the last gcache_release() -- and a caller only holds a
   * result reference while it holds the handle that pins the entry.  So
   * "entry unreferenced" implies "no reader holds a payload". */
  for (uint32_t i = 0; i < GCACHE_MAX_RESULTS; i++)
    {
      gcache_result_t *r = &e->results[i];
      if (r->data)
	{
	  dk_free (r->data, r->data_size);
	  r->data = NULL;
	}
      r->valid = false;
      r->loading = false;
      r->algo_id = 0;
      r->params_hash = 0;
      r->data_size = 0;
      r->ref_count = 0;
      r->last_use = 0;
    }

  if (e->snapshot)
    {
      graph_snapshot_release (e->snapshot);
      e->snapshot = NULL;
    }
  if (e->store)
    {
      quad_store_destroy (e->store);
      e->store = NULL;
    }
  e->graph = NULL;
  e->valid = false;
  e->loading = false;
  e->evicting = false;

  if (e->memory_bytes > 0)
    {
      g_cache.stats.current_memory -= e->memory_bytes;
      e->memory_bytes = 0;
    }
  if (g_cache.stats.current_entries > 0)
    {
      g_cache.stats.current_entries--;
    }
  gcache_update_live_locked ();
}

/* free_entry_resources() without the freeing: the resources move to rc and
 * the slot is reset at once.  Call with the cache mutex held and
 * gcache_reclaim_run() once it is released. */
static void
gcache_detach_locked (gcache_entry_t *e, gcache_reclaim_t *rc)
{
  gcache_reclaim_item_t *it;
  if (!e)
    return;
  if (!rc->items)
    {
      size_t sz = GCACHE_MAX_ENTRIES * sizeof (gcache_reclaim_item_t);
      rc->items = (gcache_reclaim_item_t *) dk_alloc (sz);
      if (rc->items)
	memset (rc->items, 0, sz);
    }
  if (!rc->items || rc->n >= GCACHE_MAX_ENTRIES)
    {
      free_entry_resources (e);
      return;
    }
  it = &rc->items[rc->n++];
  for (uint32_t i = 0; i < GCACHE_MAX_RESULTS; i++)
    {
      it->data[i] = e->results[i].data;
      it->data_size[i] = e->results[i].data_size;
      e->results[i].data = NULL;
    }
  it->snapshot = e->snapshot;
  it->store = e->store;
  e->snapshot = NULL;
  e->store = NULL;
  free_entry_resources (e);
}

static void
gcache_reclaim_run (gcache_reclaim_t *rc)
{
  if (!rc->items)
    return;
  for (int n = 0; n < rc->n; n++)
    {
      gcache_reclaim_item_t *it = &rc->items[n];
      for (uint32_t i = 0; i < GCACHE_MAX_RESULTS; i++)
	if (it->data[i])
	  {
	    dk_free (it->data[i], it->data_size[i]);
	  }
      if (it->snapshot)
	graph_snapshot_release (it->snapshot);
      if (it->store)
	quad_store_destroy (it->store);
    }
  dk_free (rc->items, GCACHE_MAX_ENTRIES * sizeof (gcache_reclaim_item_t));
  rc->items = NULL;
  rc->n = 0;
}

/* Apply what commits recorded since the last call, and reclaim entries a
 * generation bump has made stale.  Lookups refuse stale entries without
 * this; it is what keeps per-graph invalidation and memory in step.  Call
 * at the start of every lookup or publish, with the cache mutex held. */
static void
gcache_drain_locked (gcache_reclaim_t *rc)
{
  uint64_t ids[GCACHE_PENDING_MAX];
  int n = 0;
  bool overflow = false;
  uint64_t gen;
  if (s_pend.initialized && GCACHE_INT_LOAD (s_pend.n))
    {
      GCACHE_MUTEX_LOCK (s_pend.mutex);
      n = s_pend.n;
      overflow = s_pend.overflow;
      memcpy (ids, s_pend.ids, n * sizeof (uint64_t));
      s_pend.n = 0;
      s_pend.overflow = false;
      GCACHE_MUTEX_UNLOCK (s_pend.mutex);
    }
  if (overflow)
    GCACHE_GEN_BUMP ();
  gen = GCACHE_GEN_LOAD ();
  if (!n && gen == g_cache.reaped_generation)
    return;
  g_cache.reaped_generation = gen;
  for (uint32_t i = 0; i < g_cache.max_entries; i++)
    {
      gcache_entry_t *e = &g_cache.entries[i];
      bool hit = false;
      for (int k = 0; k < n; k++)
	if (e->key.graph_set_id == ids[k])
	  {
	    hit = true;
	    break;
	  }
      if (e->loading)
	{
	  /* Its loader may already have read past the write; gcache_put()
	   * must not publish it as current. */
	  if (hit)
	    e->invalidated = true;
	  continue;
	}
      if (!e->valid || !(hit || e->generation != gen))
	continue;
      if (e->ref_count == 0)
	gcache_detach_locked (e, rc);
      else
	e->evicting = true;
    }
}

/* ============================================================================
 * PUBLIC API
 * ============================================================================ */

graph_error_t
gcache_init (void)
{
  if (g_cache.initialized)
    return GRAPH_OK;

  memset (&g_cache, 0, sizeof (g_cache));
  if (!s_pend.initialized)
    {
      GCACHE_MUTEX_INIT (s_pend.mutex);
      s_pend.initialized = true;
    }
  GCACHE_MUTEX_INIT (g_cache.mutex);
  GCACHE_COND_INIT (g_cache.load_cond);
  g_cache.ttl_seconds = GCACHE_DEFAULT_TTL_SEC;
  g_cache.max_entries = GCACHE_MAX_ENTRIES;
  g_cache.max_bytes = (uint64_t) GCACHE_DEFAULT_MAX_MB *1024 * 1024;
  g_cache.initialized = true;

  return GRAPH_OK;
}

void
gcache_shutdown (void)
{
  if (!g_cache.initialized)
    return;

  GCACHE_MUTEX_LOCK (g_cache.mutex);

  for (uint32_t i = 0; i < GCACHE_MAX_ENTRIES; i++)
    {
      if (g_cache.entries[i].valid)
	{
	  free_entry_resources (&g_cache.entries[i]);
	}
    }

  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  GCACHE_COND_DESTROY (g_cache.load_cond);
  GCACHE_MUTEX_DESTROY (g_cache.mutex);

  g_cache.initialized = false;
}

static graph_error_t
gcache_get_1 (uint64_t graph_id, graph_pred_id_t predicate_id, uint64_t tx_epoch, gcache_handle_t *out_handle, gcache_reclaim_t *rc)
{
  gcache_key_t key;
  gcache_entry_t *entry;
  time_t now = time (NULL);
  if (!out_handle)
    return GRAPH_ERR_NULL_PTR;
  if (!g_cache.initialized)
    gcache_init ();
  memset (out_handle, 0, sizeof (*out_handle));
  key = gcache_make_key (graph_id, predicate_id, tx_epoch);
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  gcache_drain_locked (rc);
  entry = find_entry_locked (&key);
  if (entry && entry->expires_at > now && !entry->evicting)
    {
      if (graph_snapshot_retain (entry->snapshot) != GRAPH_OK)
	{
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_ERR_STALE_SNAPSHOT;
	}
      /* The TTL is an idle timeout, not a lifetime.  See gcache_touch(). */
      entry->ref_count++;
      entry->last_access = now;
      entry->expires_at = now + g_cache.ttl_seconds;
      g_cache.stats.hits++;
      out_handle->entry = entry;
      out_handle->snapshot = entry->snapshot;
      out_handle->owns_ref = true;
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_OK;
    }
  g_cache.stats.misses++;
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return GRAPH_ERR_NOT_FOUND;
}

graph_error_t
gcache_get (uint64_t graph_id, graph_pred_id_t predicate_id, uint64_t tx_epoch, gcache_handle_t *out_handle)
{
  gcache_reclaim_t rc = { 0 };
  graph_error_t err = gcache_get_1 (graph_id, predicate_id, tx_epoch, out_handle, &rc);
  gcache_reclaim_run (&rc);
  return err;
}

static graph_error_t
gcache_get_or_reserve_1 (uint64_t graph_set_id, graph_pred_id_t predicate_id,
    uint64_t tx_epoch, gcache_handle_t *out_handle, bool *out_is_loader, gcache_reclaim_t *rc)
{
  gcache_key_t key;
  time_t now;
  int waits;
  if (!out_handle || !out_is_loader)
    return GRAPH_ERR_NULL_PTR;
  if (!g_cache.initialized)
    gcache_init ();
  memset (out_handle, 0, sizeof (*out_handle));
  *out_is_loader = false;
  key = gcache_make_key (graph_set_id, predicate_id, tx_epoch);

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  gcache_drain_locked (rc);
  for (waits = 0;;)
    {
      gcache_entry_t *entry = find_entry_locked (&key);
      now = time (NULL);
      if (entry && entry->valid && entry->expires_at > now && !entry->evicting)
	{
	  if (graph_snapshot_retain (entry->snapshot) != GRAPH_OK)
	    {
	      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	      return GRAPH_ERR_STALE_SNAPSHOT;
	    }
	  entry->ref_count++;
	  entry->last_access = now;
	  entry->expires_at = now + g_cache.ttl_seconds;
	  g_cache.stats.hits++;
	  out_handle->entry = entry;
	  out_handle->snapshot = entry->snapshot;
	  out_handle->owns_ref = true;
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_OK;
	}
      if (entry && entry->loading)
	{
	  if (waits++ < GCACHE_MAX_WAITS)
	    {
	      GCACHE_COND_WAIT (g_cache.load_cond, g_cache.mutex);
	      continue;
	    }
	  /* Waited long enough for the other loader.  Build our own copy
	   * instead of blocking indefinitely: duplicated work, but the
	   * caller always makes progress. */
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_ERR_NOT_FOUND;
	}
      if (entry && entry->valid)
	{
	  if (entry->ref_count == 0)
	    gcache_detach_locked (entry, rc);
	  else
	    {
	      entry->evicting = true;
	      entry = NULL;
	    }
	}
      if (!entry)
	entry = find_free_slot_locked ();
      if (!entry)
	{
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_ERR_OUT_OF_MEMORY;
	}
      if (entry->valid)
	gcache_detach_locked (entry, rc);
      memset (entry, 0, sizeof (*entry));
      entry->key = key;
      entry->loading = true;
      entry->created_at = now;
      entry->last_access = now;
      /* The generation as of *now*, before the loader reads anything.
       * gcache_put() keeps this rather than re-reading the counter when
       * the entry is published: a write committing during the load bumps
       * the generation, and an entry stamped at publish time would carry
       * the new one while holding rows read before the write -- stale,
       * and indistinguishable from fresh. Stamped here it is rejected by
       * find_entry_locked() and the next reader rebuilds. */
      entry->generation = GCACHE_GEN_LOAD ();
      g_cache.stats.misses++;
      *out_is_loader = true;
      gcache_update_live_locked ();
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_NOT_FOUND;
    }
}

graph_error_t
gcache_get_or_reserve (uint64_t graph_set_id, graph_pred_id_t predicate_id,
    uint64_t tx_epoch, gcache_handle_t *out_handle, bool *out_is_loader)
{
  gcache_reclaim_t rc = { 0 };
  graph_error_t err = gcache_get_or_reserve_1 (graph_set_id, predicate_id, tx_epoch,
      out_handle, out_is_loader, &rc);
  gcache_reclaim_run (&rc);
  return err;
}

void
gcache_abort_load (uint64_t graph_set_id, graph_pred_id_t predicate_id, uint64_t tx_epoch)
{
  gcache_key_t key;
  gcache_entry_t *entry;
  if (!g_cache.initialized)
    return;
  key = gcache_make_key (graph_set_id, predicate_id, tx_epoch);
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  entry = find_entry_locked (&key);
  if (entry && entry->loading && !entry->valid)
    memset (entry, 0, sizeof (*entry));
  gcache_update_live_locked ();
  GCACHE_COND_BROADCAST (g_cache.load_cond);
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

static graph_error_t
gcache_put_1 (uint64_t graph_id, graph_pred_id_t predicate_id,
    uint64_t tx_epoch,
    quad_store_t *store, graph_t *graph, graph_snapshot_t *snapshot, gcache_handle_t *out_handle, gcache_reclaim_t *rc)
{
  gcache_key_t key;
  gcache_entry_t *entry;
  time_t now = time (NULL);
  size_t entry_bytes;
  if (!store || !graph || !snapshot || !out_handle)
    return GRAPH_ERR_NULL_PTR;
  if (!g_cache.initialized)
    gcache_init ();
  memset (out_handle, 0, sizeof (*out_handle));
  key = gcache_make_key (graph_id, predicate_id, tx_epoch);
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  gcache_drain_locked (rc);
  entry = find_entry_locked (&key);
  /* A concurrent caller can still be reading this snapshot.  Never replace
   * an entry with active handles: doing so would free its store beneath
   * those readers.  The caller retains ownership on this failure path. */
  if (entry && entry->valid && entry->ref_count != 0)
    {
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_NOT_READY;
    }
  if (!entry)
    entry = find_free_slot_locked ();
  if (!entry)
    {
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_OUT_OF_MEMORY;
    }
  if (entry->valid)
    {
      gcache_detach_locked (entry, rc);
      g_cache.stats.evictions++;
    }
  /* Stay inside the byte budget.  Without one, GCACHE_MAX_ENTRIES full
   * copies of a large graph can sit in the cache with nothing to bound
   * them.  Evict unreferenced entries oldest-first until the new snapshot
   * fits; if it still does not, decline and leave it with the caller. */
  entry_bytes = graph_snapshot_memory_bytes (snapshot);
  if (entry_bytes > g_cache.max_bytes)
    {
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_CAPACITY_EXCEEDED;
    }
  while (g_cache.stats.current_memory + entry_bytes > g_cache.max_bytes)
    {
      gcache_entry_t *victim = NULL;
      time_t victim_access = 0;
      for (uint32_t i = 0; i < GCACHE_MAX_ENTRIES; i++)
	{
	  gcache_entry_t *e = &g_cache.entries[i];
	  if (e == entry || !e->valid || e->loading || e->ref_count)
	    continue;
	  if (!victim || e->last_access < victim_access)
	    {
	      victim = e;
	      victim_access = e->last_access;
	    }
	}
      if (!victim)
	break;
      gcache_detach_locked (victim, rc);
      g_cache.stats.evictions++;
    }
  if (g_cache.stats.current_memory + entry_bytes > g_cache.max_bytes)
    {
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_CAPACITY_EXCEEDED;
    }
  if (graph_snapshot_retain (snapshot) != GRAPH_OK)
    {
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_STALE_SNAPSHOT;
    }
  entry->memory_bytes = entry_bytes;
  g_cache.stats.current_memory += entry_bytes;
  if (g_cache.stats.current_memory > g_cache.stats.peak_memory)
    g_cache.stats.peak_memory = g_cache.stats.current_memory;
  entry->key = key;
  entry->store = store;
  entry->graph = graph;
  entry->snapshot = snapshot;
  entry->created_at = now;
  entry->last_access = now;
  /* Extended on every hit, so this is when the entry would go if nothing
   * asked for it again.  See gcache_touch() above find_entry_locked(). */
  entry->expires_at = now + g_cache.ttl_seconds;
  entry->ref_count = 1;
  entry->valid = true;
  entry->evicting = false;
  /* A reserved entry already carries the generation its load started at;
   * see gcache_get_or_reserve().  Only a direct put -- one that never
   * reserved, as GRAPH_LOAD_TABLE does -- stamps it here. */
  if (!entry->loading)
    {
      entry->generation = GCACHE_GEN_LOAD ();
      entry->invalidated = false;
    }
  /* Its graph was written while it loaded (see gcache_drain_locked): the
   * caller may use what it read, nobody else may find it. */
  if (entry->invalidated)
    entry->evicting = true;
  entry->loading = false;
  g_cache.stats.loads++;
  g_cache.stats.current_entries++;
  gcache_update_live_locked ();
  out_handle->entry = entry;
  out_handle->snapshot = snapshot;
  out_handle->owns_ref = true;
  GCACHE_COND_BROADCAST (g_cache.load_cond);
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return GRAPH_OK;
}

graph_error_t
gcache_put (uint64_t graph_id, graph_pred_id_t predicate_id,
    uint64_t tx_epoch, quad_store_t *store, graph_t *graph, graph_snapshot_t *snapshot, gcache_handle_t *out_handle)
{
  gcache_reclaim_t rc = { 0 };
  graph_error_t err = gcache_put_1 (graph_id, predicate_id, tx_epoch, store, graph,
      snapshot, out_handle, &rc);
  gcache_reclaim_run (&rc);
  return err;
}

static void
gcache_release_1 (gcache_handle_t *handle, gcache_reclaim_t *rc)
{
  if (!handle || !handle->entry || !handle->owns_ref)
    return;
  if (!g_cache.initialized)
    return;

  GCACHE_MUTEX_LOCK (g_cache.mutex);

  if (handle->entry->ref_count > 0)
    {
      handle->entry->ref_count--;
    }
  if (handle->snapshot)
    graph_snapshot_release (handle->snapshot);
  if (handle->entry->evicting && handle->entry->ref_count == 0)
    {
      gcache_detach_locked (handle->entry, rc);
    }

  GCACHE_MUTEX_UNLOCK (g_cache.mutex);

  handle->entry = NULL;
  handle->snapshot = NULL;
  handle->owns_ref = false;
}

void
gcache_release (gcache_handle_t *handle)
{
  gcache_reclaim_t rc = { 0 };
  gcache_release_1 (handle, &rc);
  gcache_reclaim_run (&rc);
}

static void
gcache_invalidate_1 (uint64_t graph_id, gcache_reclaim_t *rc)
{
  if (!g_cache.initialized)
    return;

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  gcache_drain_locked (rc);

  for (uint32_t i = 0; i < GCACHE_MAX_ENTRIES; i++)
    {
      gcache_entry_t *e = &g_cache.entries[i];
      if (e->valid && e->key.graph_set_id == graph_id)
	{
	  if (e->ref_count == 0)
	    gcache_detach_locked (e, rc);
	  else
	    e->evicting = true;
	}
    }

  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

void
gcache_invalidate (uint64_t graph_id)
{
  gcache_reclaim_t rc = { 0 };
  gcache_invalidate_1 (graph_id, &rc);
  gcache_reclaim_run (&rc);
}

static void
gcache_invalidate_all_1 (gcache_reclaim_t *rc)
{
  if (!g_cache.initialized)
    return;

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  gcache_drain_locked (rc);

  for (uint32_t i = 0; i < GCACHE_MAX_ENTRIES; i++)
    {
      gcache_entry_t *e = &g_cache.entries[i];
      if (e->valid)
	{
	  if (e->ref_count == 0)
	    gcache_detach_locked (e, rc);
	  else
	    e->evicting = true;
	}
    }

  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

void
gcache_invalidate_all (void)
{
  gcache_reclaim_t rc = { 0 };
  gcache_invalidate_all_1 (&rc);
  gcache_reclaim_run (&rc);
}

void
gcache_get_stats (gcache_stats_t *stats)
{
  if (!stats)
    return;

  if (!g_cache.initialized)
    {
      memset (stats, 0, sizeof (*stats));
      return;
    }

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  *stats = g_cache.stats;
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

/* How many cached graphs' base stores actually took the dense path.
 *
 * Worth reporting because a fast path that declines is indistinguishable
 * from one that works: the answers are identical either way and only the
 * time differs, so a test that only compares answers would pass on an
 * engine where the path never ran. */
uint32_t
gcache_dense_stores (void)
{
  uint32_t i, n = 0;
  if (!g_cache.initialized)
    return 0;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  for (i = 0; i < g_cache.max_entries; i++)
    {
      const gcache_entry_t *e = &g_cache.entries[i];
      /* Current generation only.  A generation bump is what makes a
       * flag change take effect, and an entry from before it is stale
       * and about to be reloaded -- counting it would report the state
       * the flag has just left. */
      if (e->valid && !e->evicting && e->generation == GCACHE_GEN_LOAD () &&
	  e->graph && e->graph->base && e->graph->base->dense_ids)
	n++;
    }
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return n;
}

/* How many cached graphs' base stores narrowed their endpoint index
 * arrays.
 *
 * Same reason as gcache_dense_stores(): the answers are identical at
 * either width, so a test that compared only answers would pass on an
 * engine where the narrow path never ran.  memory_bytes says how much it
 * saved; this says whether it happened at all. */
uint32_t
gcache_narrow_stores (void)
{
  uint32_t i, n = 0;
  if (!g_cache.initialized)
    return 0;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  for (i = 0; i < g_cache.max_entries; i++)
    {
      const gcache_entry_t *e = &g_cache.entries[i];
      if (e->valid && !e->evicting && e->generation == GCACHE_GEN_LOAD () &&
	  e->graph && e->graph->base && e->graph->base->narrow_ix)
	n++;
    }
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return n;
}

/* Bytes the cached snapshots' node hash tables occupy.
 *
 * Zero is the interesting value: it means the tables were never built,
 * which is the whole point of the dense path and is invisible in any
 * answer the engine gives.  A test comparing results alone would pass on
 * an engine that still built all of them. */
uint64_t
gcache_node_hash_bytes (void)
{
  uint32_t i;
  uint64_t bytes = 0;
  if (!g_cache.initialized)
    return 0;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  for (i = 0; i < g_cache.max_entries; i++)
    {
      const gcache_entry_t *e = &g_cache.entries[i];
      if (e->valid && !e->evicting && e->generation == GCACHE_GEN_LOAD () && e->snapshot)
	bytes += e->snapshot->node_hash_capacity * (sizeof (graph_node_id_t) + sizeof (uint64_t));
    }
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return bytes;
}

/* Bytes the cached stores' per-edge records occupy: 16 an edge each way.
 *
 * Zero is the interesting value -- it means every cached store's edges
 * carry one predicate and none of the records were allocated, which is
 * 32 of the 40 bytes an edge and is invisible in any answer.  A test
 * comparing results alone would pass on an engine that still built all of
 * them. */
uint64_t
gcache_edge_record_bytes (void)
{
  uint32_t i;
  uint64_t bytes = 0;
  if (!g_cache.initialized)
    return 0;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  for (i = 0; i < g_cache.max_entries; i++)
    {
      const gcache_entry_t *e = &g_cache.entries[i];
      const graph_base_store_t *b;
      if (!(e->valid && !e->evicting && e->generation == GCACHE_GEN_LOAD () && e->graph && e->graph->base))
	continue;
      b = e->graph->base;
      if (b->edges)
	bytes += b->edge_capacity * sizeof (graph_edge_t);
      if (b->inv_edges)
	bytes += b->edge_capacity * sizeof (graph_inverse_edge_t);
    }
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return bytes;
}

/* How many cached graphs' base stores dropped their edge records because
 * every edge carried the same predicate.
 *
 * Reported for the reason the other two path counters are: the answers do
 * not change, so nothing in a result says whether the records were there.
 * memory_bytes says what it was worth. */
uint32_t
gcache_one_pred_stores (void)
{
  uint32_t i, n = 0;
  if (!g_cache.initialized)
    return 0;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  for (i = 0; i < g_cache.max_entries; i++)
    {
      const gcache_entry_t *e = &g_cache.entries[i];
      if (e->valid && !e->evicting && e->generation == GCACHE_GEN_LOAD () && e->graph && e->graph->base && e->graph->base->one_pred)
	n++;
    }
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return n;
}

/* Bytes the cached stores' endpoint index arrays occupy.
 *
 * The one number the narrow path exists to move, and it is invisible in
 * every answer: 4 bytes a slot against 8, over both CSR directions.
 * Reported separately from memory_bytes because that total also carries
 * entries from before a generation bump, so a test comparing the two
 * widths on one graph needs a figure that describes only the current
 * generation. */
uint64_t
gcache_edge_index_bytes (void)
{
  uint32_t i;
  uint64_t bytes = 0;
  if (!g_cache.initialized)
    return 0;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  for (i = 0; i < g_cache.max_entries; i++)
    {
      const gcache_entry_t *e = &g_cache.entries[i];
      const graph_base_store_t *b;
      if (!(e->valid && !e->evicting && e->generation == GCACHE_GEN_LOAD () && e->graph && e->graph->base))
	continue;
      b = e->graph->base;
      bytes += b->edge_capacity * GRAPH_IX_SIZE (b->narrow_ix) * (b->has_inverse ? 2 : 1);
    }
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return bytes;
}

void
gcache_set_ttl (uint32_t ttl_seconds)
{
  if (!g_cache.initialized)
    gcache_init ();

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  g_cache.ttl_seconds = ttl_seconds > 0 ? ttl_seconds : GCACHE_DEFAULT_TTL_SEC;
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

void
gcache_set_max_entries (uint32_t max_entries)
{
  if (!g_cache.initialized)
    gcache_init ();
  if (max_entries == 0)
    max_entries = 1;
  if (max_entries > GCACHE_MAX_ENTRIES)
    max_entries = GCACHE_MAX_ENTRIES;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  g_cache.max_entries = max_entries;
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

void
gcache_set_max_bytes (uint64_t max_bytes)
{
  if (!g_cache.initialized)
    gcache_init ();
  if (max_bytes < 1024 * 1024)
    max_bytes = 1024 * 1024;
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  g_cache.max_bytes = max_bytes;
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

void
gcache_increment_generation (void)
{
  gcache_reclaim_t rc = { 0 };
  GCACHE_GEN_BUMP ();
  if (!g_cache.initialized)
    return;
  /* Lookups already refuse the stale entries; this frees what nobody holds,
   * after the mutex is released.  In-flight references are safe because
   * the snapshot is immutable and refcounted. */
  GCACHE_MUTEX_LOCK (g_cache.mutex);
  gcache_drain_locked (&rc);
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  gcache_reclaim_run (&rc);
}

void
gcache_bump_generation (void)
{
  GCACHE_GEN_BUMP ();
}

void
gcache_invalidate_deferred (uint64_t graph_id)
{
  if (!s_pend.initialized)
    {
      /* No cache yet to record into, and one may be starting: be safe. */
      GCACHE_GEN_BUMP ();
      return;
    }
  GCACHE_MUTEX_LOCK (s_pend.mutex);
  if (s_pend.n < GCACHE_PENDING_MAX)
    s_pend.ids[s_pend.n++] = graph_id;
  else
    s_pend.overflow = true;
  GCACHE_MUTEX_UNLOCK (s_pend.mutex);
}

uint64_t
gcache_get_generation (void)
{
  return GCACHE_GEN_LOAD ();
}

/* ============================================================================
 * RESULT CACHE
 * ============================================================================ */

static gcache_result_t *
find_result_locked (gcache_entry_t *e, uint32_t algo_id, uint64_t params_hash)
{
  for (uint32_t i = 0; i < GCACHE_MAX_RESULTS; i++)
    {
      gcache_result_t *r = &e->results[i];
      if ((r->valid || r->loading) && r->algo_id == algo_id && r->params_hash == params_hash)
	return r;
    }
  return NULL;
}

static gcache_result_t *
find_free_result_locked (gcache_entry_t *e, bool node_keyed)
{
  /* Node-keyed results (BFS, Dijkstra) live only in the trailing
   * reserved slots; everything else only in the leading ones.  The two
   * ranges are disjoint, so an unbounded stream of source keys cannot
   * take the slot PageRank or WCC would have used.
   *
   * Within a range, an empty slot is taken first and otherwise the least
   * recently used one is reused.  A slot with readers is never a
   * candidate: its payload was handed out by pointer and is being
   * indexed with the mutex released, so freeing it here would pull the
   * data out from under them.  When every slot in the range is
   * referenced there is simply no room, and the caller computes without
   * caching. */
  uint32_t first = node_keyed ? GCACHE_MAX_RESULTS - GCACHE_NODE_KEYED_RESULTS : 0;
  uint32_t last = node_keyed ? GCACHE_MAX_RESULTS : GCACHE_MAX_RESULTS - GCACHE_NODE_KEYED_RESULTS;
  gcache_result_t *victim = NULL;
  for (uint32_t i = first; i < last; i++)
    {
      gcache_result_t *r = &e->results[i];
      if (!r->valid && !r->loading && 0 == r->ref_count)
	return r;
      if (r->valid && !r->loading && 0 == r->ref_count && (NULL == victim || r->last_use < victim->last_use))
	victim = r;
    }
  if (!victim)
    return NULL;
  if (victim->data)
    dk_free (victim->data, victim->data_size);
  memset (victim, 0, sizeof (*victim));
  g_cache.stats.result_evictions++;
  return victim;
}

graph_error_t
gcache_result_get (gcache_handle_t *handle, uint32_t algo_id, uint64_t params_hash, bool node_keyed, gcache_result_t *out)
{
  gcache_entry_t *e;
  gcache_result_t *r;
  int waits;
  if (!handle || !handle->entry || !out)
    return GRAPH_ERR_NULL_PTR;
  if (!g_cache.initialized)
    gcache_init ();
  memset (out, 0, sizeof (*out));
  e = handle->entry;

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  for (waits = 0;;)
    {
      r = find_result_locked (e, algo_id, params_hash);
      if (r && r->valid)
	{
	  /* Cache hit.  The payload is handed out by pointer, so take a
	   * reference: until gcache_result_release() the slot cannot be
	   * reused for another key. */
	  r->ref_count++;
	  r->last_use = ++g_cache.result_clock;
	  g_cache.stats.result_hits++;
	  out->algo_id = r->algo_id;
	  out->params_hash = r->params_hash;
	  out->data = r->data;
	  out->data_size = r->data_size;
	  out->valid = true;
	  out->loading = false;
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_OK;
	}
      if (r && r->loading)
	{
	  /* Another caller is computing; wait, but not forever. */
	  if (waits++ < GCACHE_MAX_WAITS)
	    {
	      GCACHE_COND_WAIT (g_cache.load_cond, g_cache.mutex);
	      continue;
	    }
	  /* Give up on the other computation and run our own without
	   * reserving a slot; the result simply is not cached. */
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_ERR_NOT_READY;
	}
      /* No entry: reserve a free slot as loading.  Counted as a miss
       * here rather than on the put, so that a computation which is
       * reserved and then aborted still shows as work the cache did
       * not save. */
      g_cache.stats.result_misses++;
      r = find_free_result_locked (e, node_keyed);
      if (!r)
	{
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_ERR_OUT_OF_MEMORY;
	}
      memset (r, 0, sizeof (*r));
      r->algo_id = algo_id;
      r->params_hash = params_hash;
      r->loading = true;
      out->algo_id = algo_id;
      out->params_hash = params_hash;
      out->data = NULL;
      out->data_size = 0;
      out->valid = false;
      out->loading = true;
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_NOT_FOUND;
    }
}

graph_error_t
gcache_result_put (gcache_handle_t *handle, uint32_t algo_id, uint64_t params_hash, bool node_keyed, void *data, size_t data_size)
{
  gcache_entry_t *e;
  gcache_result_t *r;
  if (!handle || !handle->entry || !data)
    return GRAPH_ERR_NULL_PTR;
  e = handle->entry;

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  r = find_result_locked (e, algo_id, params_hash);
  if (!r)
    {
      r = find_free_result_locked (e, node_keyed);
      if (!r)
	{
	  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
	  return GRAPH_ERR_OUT_OF_MEMORY;
	}
      memset (r, 0, sizeof (*r));
      r->algo_id = algo_id;
      r->params_hash = params_hash;
    }
  /* Never replace a payload a reader still holds.  The reserve/publish
   * protocol means the slot this caller reserved is empty, so this does
   * not arise; if it ever did, leaving the data with the caller is the
   * only safe answer. */
  if (r->data && r->ref_count > 0)
    {
      GCACHE_MUTEX_UNLOCK (g_cache.mutex);
      return GRAPH_ERR_NOT_READY;
    }
  /* If there was a previous valid result, free it. */
  if (r->data)
    {
      dk_free (r->data, r->data_size);
    }
  r->data = data;
  r->data_size = data_size;
  r->valid = true;
  r->loading = false;
  r->last_use = ++g_cache.result_clock;
  GCACHE_COND_BROADCAST (g_cache.load_cond);
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
  return GRAPH_OK;
}

/* Drop the reference gcache_result_get() took on a hit.  The slot is found
 * by key rather than by pointer, which is exact: a referenced slot cannot
 * have been reused for another key, and the entry cannot have been freed
 * while the caller still holds the handle that pins it. */
void
gcache_result_release (gcache_handle_t *handle, uint32_t algo_id, uint64_t params_hash)
{
  gcache_entry_t *e;
  gcache_result_t *r;
  if (!handle || !handle->entry)
    return;
  if (!g_cache.initialized)
    return;
  e = handle->entry;

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  r = find_result_locked (e, algo_id, params_hash);
  if (r && r->ref_count > 0)
    r->ref_count--;
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

void
gcache_result_abort (gcache_handle_t *handle, uint32_t algo_id, uint64_t params_hash)
{
  gcache_entry_t *e;
  gcache_result_t *r;
  if (!handle || !handle->entry)
    return;
  e = handle->entry;

  GCACHE_MUTEX_LOCK (g_cache.mutex);
  r = find_result_locked (e, algo_id, params_hash);
  if (r && r->loading && !r->valid)
    memset (r, 0, sizeof (*r));
  GCACHE_COND_BROADCAST (g_cache.load_cond);
  GCACHE_MUTEX_UNLOCK (g_cache.mutex);
}

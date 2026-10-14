/*
 *  vvec_hnsw.h -- standalone in-memory parallel HNSW builder (perf phase 3 prototype).
 *
 *  A pure-memory HNSW graph (vectors + per-node neighbour lists in RAM, no DB pages,
 *  no buffer manager, no transaction) built with a worker pool -- the hnswlib/FAISS
 *  model. It proves the approach and the multi-core build speedup in isolation, before
 *  the risk of wiring a page-serializer + atomic publish into the engine. Distances
 *  use the SIMD float32 kernels from vvec_simd.h.
 *
 *  Rule 7: the build fan-out uses the Virtuoso threading runtime (thread_create +
 *  a completion semaphore) and Virtuoso mutexes (dk_mutex_t), not raw pthreads, so
 *  the workers are runtime-visible.  This header is included by libsrc/Wi/vvec.c,
 *  after the core Dk/Thread headers, so those primitives are in scope.
 *
 *  Concurrency (hnswlib model): each point is linked by one worker; a node's
 *  neighbour list is locked only while it is MODIFIED (adding a back-link / pruning);
 *  reads during search are unlocked and tolerate a transient race, because links are
 *  only ever valid node ids and the search is approximate. The entry point / max
 *  level are updated under a single global lock. Vectors, magnitudes and levels are
 *  assigned before the parallel link phase, so those arrays are read-only during it.
 *
 */
#ifndef VVEC_HNSW_H
#define VVEC_HNSW_H

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "vvec_simd.h"

#define VVEC_HM_COSINE 0
#define VVEC_HM_L2     1
#define VVEC_HM_L1     2

/* Nodes between graph-build progress lines.  Cheap: one modulo per node on a
   counter the worker already holds, and ~20 lines over a 10M-node build. */
#define VH_PROGRESS_EVERY 500000

typedef struct { int cnt; int *ids; } vh_row_t;   /* neighbours at one level */

typedef struct
{
  int dim, M, M0, efc, metric;
  int cap, count;
  int entry, max_level;
  float *vecs;                 /* cap*dim, native float32 */
  int owns_vecs;               /* false when bulk rebuild lends its input arena */
  float *mags;                 /* cap */
  int *level;                  /* cap */
  vh_row_t **rows;             /* cap; rows[i] has level[i]+1 vh_row_t */
  dk_mutex_t *locks;           /* cap, per-node link lock */
  dk_mutex_t glob;             /* entry / max_level */
  unsigned int rng;
  double levelmult;
} vvec_hnsw_t;

/* ---- small deterministic RNG (thread use only in level assignment, single-thread) ---- */
static double
vh_rand01 (unsigned int *s)
{
  *s = *s * 1103515245u + 12345u;
  return ((*s >> 8) & 0xffffff) / (double) 0x1000000;
}

static int
vh_row_cap (vvec_hnsw_t * h, int level)
{
  return level ? h->M : h->M0;
}

static void
vvec_hnsw_init (vvec_hnsw_t * h, int dim, int M, int efc, int metric, int cap,
    const float * borrowed_vecs)
{
  int i;
  memset (h, 0, sizeof (*h));
  h->dim = dim; h->M = M; h->M0 = 2 * M; h->efc = efc; h->metric = metric;
  h->cap = cap; h->count = 0; h->entry = -1; h->max_level = 0;
  h->rng = 0x9e3779b9u;
  h->levelmult = 1.0 / log ((double) (M > 1 ? M : 2));
  /* The bulk caller lends its immutable vector arena so a 10M-row build does
     not hold a second full copy.  Standalone callers may still request an owned
     Dk arena by passing NULL.  Per-node structures use libsrc/Dk accounting;
     transient search scratch stays on malloc (see vh_heap_init). */
  h->owns_vecs = borrowed_vecs ? 0 : 1;
  h->vecs = borrowed_vecs ? (float *) borrowed_vecs
                          : (float *) dk_alloc ((size_t) cap * dim * sizeof (float));
  h->mags = (float *) dk_alloc ((size_t) cap * sizeof (float));
  h->level = (int *) dk_alloc ((size_t) cap * sizeof (int));
  h->rows = (vh_row_t **) dk_alloc ((size_t) cap * sizeof (vh_row_t *));
  h->locks = (dk_mutex_t *) dk_alloc ((size_t) cap * sizeof (dk_mutex_t));
  for (i = 0; i < cap; i++)
    { h->rows[i] = NULL; dk_mutex_init (&h->locks[i], MUTEX_TYPE_SHORT); }
  dk_mutex_init (&h->glob, MUTEX_TYPE_SHORT);
}

/* store one point (single-threaded, before the link phase). Assigns its level. */
static void
vvec_hnsw_set (vvec_hnsw_t * h, int id, const float * vec)
{
  int lvl, l;
  if (h->owns_vecs)
    memcpy (h->vecs + (size_t) id * h->dim, vec, (size_t) h->dim * sizeof (float));
  h->mags[id] = vvec_norm_f32 (vec, h->dim);
  lvl = (int) (-log (vh_rand01 (&h->rng) + 1e-30) * h->levelmult);
  if (lvl > 63) lvl = 63;
  h->level[id] = lvl;
  h->rows[id] = (vh_row_t *) dk_alloc ((size_t) (lvl + 1) * sizeof (vh_row_t));
  for (l = 0; l <= lvl; l++)
    { h->rows[id][l].cnt = 0; h->rows[id][l].ids = (int *) dk_alloc ((size_t) vh_row_cap (h, l) * sizeof (int)); }
  if (id + 1 > h->count) h->count = id + 1;
}

static float
vh_dist_vm (vvec_hnsw_t * h, const float * qv, float qmag, int j)
{
  const float * b = h->vecs + (size_t) j * h->dim;
  if (VVEC_HM_L2 == h->metric)
    return (float) sqrt ((double) vvec_l2sqr_f32 (qv, b, h->dim));
  if (VVEC_HM_L1 == h->metric)
    return vvec_l1_f32 (qv, b, h->dim);
  {
    double ip = (double) vvec_ip_f32 (qv, b, h->dim);
    float bm = h->mags[j];
    return (!qmag || !bm) ? 2.0f : (float) (1.0 - (ip / (((double) qmag) * ((double) bm))));
  }
}

/* ---------- binary heaps of (dist,id); max-heap for the result set, min-heap for the frontier ----------
 *
 * Rule 8 note: the transient per-operation scratch below (search/insert heaps,
 * candidate buffers, the visited array) deliberately stays on malloc/realloc rather
 * than libsrc/Dk.  It is allocated, grown (realloc) and freed inside the parallel
 * link/search inner loop -- the hot path -- and libsrc/Dk has no realloc analogue, so
 * keeping it on the C allocator avoids hand-rolled grow/copy in the tightest loop.
 * The dominant memory -- the build arena in vvec_hnsw_init -- is on Dk.  (The build
 * workers are Virtuoso threads, so dk_alloc here would be safe; this is a hot-path
 * choice, not a thread-context one.) */
typedef struct { float d; int id; } vh_pair_t;

typedef struct { vh_pair_t * a; int n, cap; int is_max; } vh_heap_t;

static void vh_heap_init (vh_heap_t * h, int cap, int is_max)
{ h->a = (vh_pair_t *) malloc ((size_t) cap * sizeof (vh_pair_t)); h->n = 0; h->cap = cap; h->is_max = is_max; }
static void vh_heap_free (vh_heap_t * h) { free (h->a); }
static int vh_before (vh_heap_t * h, float x, float y) { return h->is_max ? x > y : x < y; }
static void vh_push (vh_heap_t * h, float d, int id)
{
  int i, p;
  if (h->n == h->cap) { h->cap *= 2; h->a = (vh_pair_t *) realloc (h->a, (size_t) h->cap * sizeof (vh_pair_t)); }
  i = h->n++; h->a[i].d = d; h->a[i].id = id;
  while (i > 0) { p = (i - 1) / 2; if (vh_before (h, h->a[i].d, h->a[p].d)) { vh_pair_t t = h->a[i]; h->a[i] = h->a[p]; h->a[p] = t; i = p; } else break; }
}
static vh_pair_t vh_top (vh_heap_t * h) { return h->a[0]; }
static vh_pair_t vh_pop (vh_heap_t * h)
{
  vh_pair_t top = h->a[0]; int i = 0, l, r, m;
  h->a[0] = h->a[--h->n];
  for (;;)
    {
      vh_pair_t t;
      l = 2 * i + 1; r = l + 1; m = i;
      if (l < h->n && vh_before (h, h->a[l].d, h->a[m].d))
	m = l;
      if (r < h->n && vh_before (h, h->a[r].d, h->a[m].d))
	m = r;
      if (m == i)
	break;
      t = h->a[i]; h->a[i] = h->a[m]; h->a[m] = t;
      i = m;
    }
  return top;
}

/* per-thread scratch: a generation-stamped visited array (O(1) reset). */
typedef struct { int * gen; int cur; int cap; } vh_visited_t;
static void vh_vis_init (vh_visited_t * v, int cap) { v->gen = (int *) calloc ((size_t) cap, sizeof (int)); v->cur = 0; v->cap = cap; }
static void vh_vis_free (vh_visited_t * v) { free (v->gen); }
static void vh_vis_reset (vh_visited_t * v) { v->cur++; }
static int vh_seen (vh_visited_t * v, int id) { if (v->gen[id] == v->cur) return 1; v->gen[id] = v->cur; return 0; }

/* greedy 1-nearest descent on one upper layer; returns the closest node found. */
static int
vh_greedy (vvec_hnsw_t * h, const float * qv, float qmag, int ep, int level)
{
  int changed = 1, best = ep;
  float bestd = vh_dist_vm (h, qv, qmag, ep);
  while (changed)
    {
      vh_row_t * row;
      int i;
      changed = 0;
      if (level > h->level[best]) break;         /* best has no such layer */
      row = &h->rows[best][level];
      for (i = 0; i < row->cnt; i++)
	{
	  int e = row->ids[i];
	  float d = vh_dist_vm (h, qv, qmag, e);
	  if (d < bestd) { bestd = d; best = e; changed = 1; }
	}
    }
  return best;
}

/* ef search on one layer from entry ep; fills result max-heap W (size<=ef). */
static void
vh_search_layer (vvec_hnsw_t * h, const float * qv, float qmag, int ep, int ef, int level,
    vh_visited_t * vis, vh_heap_t * W)
{
  vh_heap_t C;                       /* frontier: min-heap */
  float d0 = vh_dist_vm (h, qv, qmag, ep);
  vh_heap_init (&C, ef + 16, 0);
  vh_vis_reset (vis);
  vh_seen (vis, ep);
  vh_push (&C, d0, ep);
  vh_push (W, d0, ep);
  while (C.n)
    {
      vh_pair_t c = vh_pop (&C);
      vh_row_t * row;
      int i;
      if (c.d > vh_top (W).d && W->n >= ef) break;
      if (level > h->level[c.id]) continue;
      row = &h->rows[c.id][level];
      for (i = 0; i < row->cnt; i++)
	{
	  int e = row->ids[i];
	  float d;
	  if (e < 0 || e >= h->count) continue;      /* tolerate a torn read */
	  if (vh_seen (vis, e)) continue;
	  d = vh_dist_vm (h, qv, qmag, e);
	  if (W->n < ef || d < vh_top (W).d)
	    {
	      vh_push (&C, d, e);
	      vh_push (W, d, e);
	      if (W->n > ef) vh_pop (W);
	    }
	}
    }
  vh_heap_free (&C);
}

/* hnswlib neighbour-selection heuristic: keep a candidate only if it is closer to q
   than to any already-kept neighbour. cand[] must be sorted nearest-first. */
static int
vh_select (vvec_hnsw_t * h, vh_pair_t * cand, int ncand, int m, int * out)
{
  int nsel = 0, i, j;
  for (i = 0; i < ncand && nsel < m; i++)
    {
      int keep = 1;
      const float * cv = h->vecs + (size_t) cand[i].id * h->dim;
      float cmag = h->mags[cand[i].id];
      for (j = 0; j < nsel; j++)
	{
	  float dto = vh_dist_vm (h, cv, cmag, out[j]);
	  if (dto < cand[i].d) { keep = 0; break; }
	}
      if (keep) out[nsel++] = cand[i].id;
    }
  return nsel;
}

static int vh_cmp_pair (const void * a, const void * b)
{ float x = ((const vh_pair_t *) a)->d, y = ((const vh_pair_t *) b)->d; return x < y ? -1 : (x > y ? 1 : 0); }

/* add id's outgoing links at a level + reciprocal back-links (with pruning). */
static void
vh_connect (vvec_hnsw_t * h, int id, int level, vh_pair_t * cand, int ncand)
{
  int sel[128];
  int nsel, i;
  int m = vh_row_cap (h, level);
  qsort (cand, ncand, sizeof (vh_pair_t), vh_cmp_pair);
  nsel = vh_select (h, cand, ncand, h->M, sel);        /* pick up to M for id's own row */
  /* id is not yet reachable from anyone, so its row needs no lock */
  memcpy (h->rows[id][level].ids, sel, (size_t) nsel * sizeof (int));
  h->rows[id][level].cnt = nsel;
  for (i = 0; i < nsel; i++)
    {
      int n = sel[i];
      vh_row_t * nr;
      mutex_enter (&h->locks[n]);
      if (level <= h->level[n])
	{
	  nr = &h->rows[n][level];
	  if (nr->cnt < m)
	    nr->ids[nr->cnt++] = id;                 /* room: just append */
	  else
	    {
	      /* full: re-select among existing neighbours + id */
	      vh_pair_t tmp[256];
	      int t = 0, k, keep[128], nk;
	      const float * nv = h->vecs + (size_t) n * h->dim;
	      float nmag = h->mags[n];
	      for (k = 0; k < nr->cnt && t < 256; k++)
		{ tmp[t].id = nr->ids[k]; tmp[t].d = vh_dist_vm (h, nv, nmag, nr->ids[k]); t++; }
	      if (t < 256) { tmp[t].id = id; tmp[t].d = vh_dist_vm (h, nv, nmag, id); t++; }
	      qsort (tmp, t, sizeof (vh_pair_t), vh_cmp_pair);
	      nk = vh_select (h, tmp, t, m, keep);
	      memcpy (nr->ids, keep, (size_t) nk * sizeof (int));
	      nr->cnt = nk;
	    }
	}
      mutex_leave (&h->locks[n]);
    }
}

/* link one already-stored point into the graph (parallel-safe). */
static void
vvec_hnsw_add (vvec_hnsw_t * h, int id, vh_visited_t * vis)
{
  const float * qv = h->vecs + (size_t) id * h->dim;
  float qmag = h->mags[id];
  int L = h->level[id];
  int cur, lvl, ep, cur_max;
  mutex_enter (&h->glob);
  ep = h->entry; cur_max = h->max_level;
  mutex_leave (&h->glob);
  if (ep < 0)      /* first point */
    { mutex_enter (&h->glob); if (h->entry < 0) { h->entry = id; h->max_level = L; } mutex_leave (&h->glob); return; }
  cur = ep;
  for (lvl = cur_max; lvl > L; lvl--)
    cur = vh_greedy (h, qv, qmag, cur, lvl);
  for (lvl = (L < cur_max ? L : cur_max); lvl >= 0; lvl--)
    {
      vh_heap_t W;
      vh_pair_t * cand;
      int nc, i;
      vh_heap_init (&W, h->efc + 16, 1);
      vh_search_layer (h, qv, qmag, cur, h->efc, lvl, vis, &W);
      nc = W.n;
      cand = (vh_pair_t *) malloc ((size_t) nc * sizeof (vh_pair_t));
      for (i = 0; i < nc; i++) cand[i] = W.a[i];
      vh_connect (h, id, lvl, cand, nc);
      /* nearest of W is the entry for the next lower layer */
      { int nearest = cur; float bd = 1e30f; for (i = 0; i < nc; i++) if (cand[i].d < bd) { bd = cand[i].d; nearest = cand[i].id; } cur = nearest; }
      free (cand);
      vh_heap_free (&W);
    }
  if (L > cur_max)
    { mutex_enter (&h->glob); if (L > h->max_level) { h->max_level = L; h->entry = id; } mutex_leave (&h->glob); }
}

/* top-k search for the recall test. */
static int
vvec_hnsw_search (vvec_hnsw_t * h, const float * qv, int k, int ef, int * out_ids, vh_visited_t * vis)
{
  float qmag = vvec_norm_f32 (qv, h->dim);
  int cur, lvl, i, n;
  vh_heap_t W;
  vh_pair_t * arr;
  if (h->entry < 0) return 0;
  cur = h->entry;
  for (lvl = h->max_level; lvl > 0; lvl--)
    cur = vh_greedy (h, qv, qmag, cur, lvl);
  vh_heap_init (&W, ef + 16, 1);
  vh_search_layer (h, qv, qmag, cur, ef, 0, vis, &W);
  n = W.n; arr = (vh_pair_t *) malloc ((size_t) n * sizeof (vh_pair_t));
  for (i = 0; i < n; i++) arr[i] = W.a[i];
  qsort (arr, n, sizeof (vh_pair_t), vh_cmp_pair);
  if (k > n) k = n;
  for (i = 0; i < k; i++) out_ids[i] = arr[i].id;
  free (arr); vh_heap_free (&W);
  return k;
}

/* ---------------- parallel build over ids 0..count-1 ---------------- */
typedef struct { vvec_hnsw_t * h; int * next; dk_mutex_t * nlk; int n; semaphore_t * done; } vh_work_t;

/* the shared draining loop: pull the next id under nlk, link it, repeat. */
static void
vh_worker_loop (vh_work_t * w)
{
  vh_visited_t vis;
  vh_vis_init (&vis, w->h->cap);
  for (;;)
    {
      int id;
      mutex_enter (w->nlk);
      id = (*w->next)++;
      mutex_leave (w->nlk);
      if (id >= w->n) break;
      /* One line per VH_PROGRESS_EVERY nodes, from whichever worker crosses the
         boundary.  A multi-hour build is otherwise silent until it finishes,
         and reading the shared counter meant attaching a debugger. */
      if (w->n > VH_PROGRESS_EVERY && 0 == (id % VH_PROGRESS_EVERY) && id)
        log_info ("Vector index graph build: %d of %d nodes (%d%%)",
            id, w->n, (int) ((int64) id * 100 / w->n));
      vvec_hnsw_add (w->h, id, &vis);
    }
  vh_vis_free (&vis);
}

/* Virtuoso worker-thread entry (thread_init_func: int (*)(void *)).  Runs the
   drain loop, then signals the caller's completion semaphore.  The thread is
   recycled by the runtime when this returns. */
static int
vh_worker_thread (void * arg)
{
  vh_work_t * w = (vh_work_t *) arg;
  vh_worker_loop (w);
  semaphore_leave (w->done);
  return 0;
}

static void
vvec_hnsw_build (vvec_hnsw_t * h, int nthreads)
{
  /* point 0 seeds the entry before the pool runs, so every worker sees a graph. */
  vh_visited_t vis0;
  vh_work_t w;
  dk_mutex_t nlk;
  int next = 1, i;
  vh_vis_init (&vis0, h->cap);
  vvec_hnsw_add (h, 0, &vis0);
  vh_vis_free (&vis0);
  if (nthreads < 1) nthreads = 1;
  if (nthreads > 64) nthreads = 64;
  dk_mutex_init (&nlk, MUTEX_TYPE_SHORT);
  w.h = h; w.next = &next; w.nlk = &nlk; w.n = h->count; w.done = NULL;
  if (nthreads == 1)
    vh_worker_loop (&w);
  else
    {
      /* Spawn workers on the Virtuoso thread runtime and join via a completion
         semaphore -- there is no spawn/join-once primitive, so each worker signals
         once on exit and the caller waits that many times.  This (rebuild) thread
         also drains the queue: it keeps a CPU busy and covers any worker the runtime
         could not create, so the build always completes. */
      int started = 0;
      w.done = semaphore_allocate (0);
      for (i = 0; i < nthreads - 1; i++)
        if (thread_create ((thread_init_func) vh_worker_thread, 0, &w))
          started++;
      vh_worker_loop (&w);
      for (i = 0; i < started; i++)
        semaphore_enter (w.done);
      semaphore_free (w.done);
    }
  dk_mutex_destroy (&nlk);
}

static void
vvec_hnsw_free (vvec_hnsw_t * h)
{
  int i, l;
  for (i = 0; i < h->count; i++)
    if (h->rows[i])
      {
	for (l = 0; l <= h->level[i]; l++)
	  dk_free (h->rows[i][l].ids, (size_t) vh_row_cap (h, l) * sizeof (int));
	dk_free (h->rows[i], (size_t) (h->level[i] + 1) * sizeof (vh_row_t));
      }
  for (i = 0; i < h->cap; i++) dk_mutex_destroy (&h->locks[i]);
  if (h->owns_vecs)
    dk_free (h->vecs, (size_t) h->cap * h->dim * sizeof (float));
  dk_free (h->mags, (size_t) h->cap * sizeof (float));
  dk_free (h->level, (size_t) h->cap * sizeof (int));
  dk_free (h->rows, (size_t) h->cap * sizeof (vh_row_t *));
  dk_free (h->locks, (size_t) h->cap * sizeof (dk_mutex_t));
  dk_mutex_destroy (&h->glob);
}

#endif /* VVEC_HNSW_H */

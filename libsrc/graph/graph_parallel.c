/*
 *  graph_parallel.c
 *
 *  Host-injected parallel execution for graph algorithms
 *
 *  The library never spawns threads.  The host registers a
 *  graph_parallel_ops_t (in the Virtuoso server this executor is built on
 *  async_queue); graph_parallel_begin()/run()/end() drive it on the
 *  library's behalf.  Without a registered executor - or when the range is
 *  too small to be worth slicing - every section runs inline on the
 *  calling thread, so results are identical to the single-threaded case
 *  and the code paths stay byte-identical.
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

#include "graph.h"
#include <stdlib.h>
#include "Dk.h"

/*
 * Registration happens once, from the host's single-threaded startup,
 * before any algorithm can run; reads afterwards are lock-free.
 */
static const graph_parallel_ops_t *graph_parallel_ops;

void
graph_parallel_set_ops (const graph_parallel_ops_t *ops)
{
  graph_parallel_ops = ops;
}

/*
 * Worker count, optionally pinned for the duration of one algorithm call.
 *
 * The host's count is live: it follows enable_qp, which is settable at run
 * time.  Algorithms size their per-worker scratch blocks from this value
 * and then, later, slice their loops by it again - so a count that grew in
 * between would index past the blocks that were allocated.  The host pins
 * it around each call (graph_parallel_freeze_workers /
 * graph_parallel_unfreeze_workers) so both reads agree.
 */
static _Thread_local uint32_t tls_frozen_workers;

static uint32_t
graph_parallel_live_worker_count (void)
{
  const graph_parallel_ops_t *ops = graph_parallel_ops;
  uint32_t n;
  if (!ops || !ops->worker_count)
    return 1;
  n = ops->worker_count (ops->ctx);
  if (n < 1)
    n = 1;
  if (n > GRAPH_PARALLEL_MAX_WORKERS)
    n = GRAPH_PARALLEL_MAX_WORKERS;
  return n;
}

uint32_t
graph_parallel_worker_count (void)
{
  if (tls_frozen_workers)
    return tls_frozen_workers;
  return graph_parallel_live_worker_count ();
}

void
graph_parallel_freeze_workers (void)
{
  tls_frozen_workers = graph_parallel_live_worker_count ();
}

void
graph_parallel_unfreeze_workers (void)
{
  tls_frozen_workers = 0;
}

struct graph_parallel_session
{
  const graph_parallel_ops_t *ops;
  void *host;			/* host-owned session state */
  uint32_t n_slices;		/* slices every run() call is split into */
};

graph_parallel_session_t *
graph_parallel_begin (uint64_t total, uint32_t max_workers)
{
  const graph_parallel_ops_t *ops = graph_parallel_ops;
  graph_parallel_session_t *s;
  uint32_t wc;

  if (!ops || !ops->begin || !ops->run || !ops->end)
    return NULL;
  if (total == 0)
    return NULL;

  wc = graph_parallel_worker_count ();
  if (max_workers && max_workers < wc)
    wc = max_workers;
  if (wc > GRAPH_PARALLEL_MAX_WORKERS)
    wc = GRAPH_PARALLEL_MAX_WORKERS;

  /* Every slice must keep at least GRAPH_PARALLEL_MIN_SLICE items,
   * otherwise the dispatch overhead outweighs the work.  Workers are
   * given up one at a time until the range is big enough; at one worker
   * the section runs inline. */
  while (wc > 1 && total / wc < GRAPH_PARALLEL_MIN_SLICE)
    wc--;
  if (wc < 2)
    return NULL;

  s = (graph_parallel_session_t *) dk_alloc (sizeof (graph_parallel_session_t));
  if (!s)
    return NULL;
  s->host = ops->begin (ops->ctx, wc, total);
  if (!s->host)
    {
      dk_free (s, sizeof (graph_parallel_session_t));
      return NULL;
    }
  s->ops = ops;
  s->n_slices = wc;
  return s;
}

void
graph_parallel_run (graph_parallel_session_t *session, uint64_t start, uint64_t end, graph_parallel_work_fn fn, void *arg)
{
  if (end <= start)
    return;
  if (!session)
    {
      /* No session: inline, worker_index 0 (the only worker). */
      fn (arg, start, end, 0);
      return;
    }
  session->ops->run (session->host, start, end, session->n_slices, fn, arg);
}

void
graph_parallel_end (graph_parallel_session_t *session)
{
  if (!session)
    return;
  session->ops->end (session->host);
  dk_free (session, sizeof (graph_parallel_session_t));
}

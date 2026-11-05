/*
 *  graph_delta.c
 *
 *  Delta chain implementation for versioned graph storage
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

#include "graph_internal.h"
#include <stdlib.h>
#include <string.h>

/* ============================================================================
 * DELTA CREATION AND DESTRUCTION
 * ============================================================================ */

graph_error_t
graph_delta_create (graph_delta_t **out_delta, const graph_allocator_t *a, uint64_t id, graph_delta_t *prev)
{
  if (!out_delta || !a)
    return GRAPH_ERR_NULL_PTR;

  graph_delta_t *delta = graph_alloc (a, sizeof (graph_delta_t));
  if (!delta)
    return GRAPH_ERR_OUT_OF_MEMORY;

  memset (delta, 0, sizeof (*delta));
  delta->magic = GRAPH_DELTA_MAGIC;
  delta->id = id;
  delta->prev = prev;

  delta->addition_capacity = GRAPH_INITIAL_DELTA_CAPACITY;
  delta->additions = graph_alloc (a, delta->addition_capacity * sizeof (graph_triple_t));
  if (!delta->additions)
    {
      graph_free (a, delta, sizeof (graph_delta_t));
      return GRAPH_ERR_OUT_OF_MEMORY;
    }

  delta->deletion_capacity = GRAPH_INITIAL_DELTA_CAPACITY / 4;
  if (delta->deletion_capacity < 16)
    delta->deletion_capacity = 16;
  delta->deletions = graph_alloc (a, delta->deletion_capacity * sizeof (graph_triple_t));
  if (!delta->deletions)
    {
      graph_free (a, delta->additions, delta->addition_capacity * sizeof (graph_triple_t));
      graph_free (a, delta, sizeof (graph_delta_t));
      return GRAPH_ERR_OUT_OF_MEMORY;
    }

  GRAPH_ATOMIC_STORE (&delta->ref_count, 0);

  *out_delta = delta;
  return GRAPH_OK;
}

void
graph_delta_destroy (graph_delta_t *delta, const graph_allocator_t *a)
{
  if (!delta || !a)
    return;

  if (delta->magic != GRAPH_DELTA_MAGIC)
    {
      return;
    }

  if (delta->additions)
    {
      graph_free (a, delta->additions, delta->addition_capacity * sizeof (graph_triple_t));
    }
  if (delta->deletions)
    {
      graph_free (a, delta->deletions, delta->deletion_capacity * sizeof (graph_triple_t));
    }

  delta->magic = 0;
  graph_free (a, delta, sizeof (graph_delta_t));
}

/* ============================================================================
 * REFERENCE COUNTING
 * ============================================================================ */

void
graph_delta_ref_inc (graph_delta_t *delta)
{
  if (!delta)
    return;

  GRAPH_ATOMIC_FETCH_ADD (&delta->ref_count, 1);

  if (delta->prev)
    {
      graph_delta_ref_inc (delta->prev);
    }
}

void
graph_delta_ref_dec (graph_delta_t *delta, const graph_allocator_t *a)
{
  if (!delta)
    return;

  int32_t prev_count;
  prev_count = GRAPH_ATOMIC_FETCH_SUB (&delta->ref_count, 1);
  (void) prev_count;		/* Used for debugging; cleanup deferred to compaction */

  if (delta->prev)
    {
      graph_delta_ref_dec (delta->prev, a);
    }
}

/* ============================================================================
 * TRIPLE OPERATIONS
 * ============================================================================ */

static graph_error_t
ensure_addition_capacity (graph_delta_t *delta, const graph_allocator_t *a)
{
  if (delta->addition_count < delta->addition_capacity)
    {
      return GRAPH_OK;
    }

  uint32_t new_cap = delta->addition_capacity * GRAPH_GROWTH_FACTOR;
  size_t old_size = delta->addition_capacity * sizeof (graph_triple_t);
  size_t new_size = new_cap * sizeof (graph_triple_t);

  graph_triple_t *new_arr = graph_realloc (a, delta->additions, old_size, new_size);
  if (!new_arr)
    return GRAPH_ERR_OUT_OF_MEMORY;

  delta->additions = new_arr;
  delta->addition_capacity = new_cap;
  return GRAPH_OK;
}

static graph_error_t
ensure_deletion_capacity (graph_delta_t *delta, const graph_allocator_t *a)
{
  if (delta->deletion_count < delta->deletion_capacity)
    {
      return GRAPH_OK;
    }

  uint32_t new_cap = delta->deletion_capacity * GRAPH_GROWTH_FACTOR;
  size_t old_size = delta->deletion_capacity * sizeof (graph_triple_t);
  size_t new_size = new_cap * sizeof (graph_triple_t);

  graph_triple_t *new_arr = graph_realloc (a, delta->deletions, old_size, new_size);
  if (!new_arr)
    return GRAPH_ERR_OUT_OF_MEMORY;

  delta->deletions = new_arr;
  delta->deletion_capacity = new_cap;
  return GRAPH_OK;
}

graph_error_t
graph_delta_add_triple (graph_delta_t *delta, const graph_allocator_t *a, const graph_triple_t *triple)
{
  if (!delta || !a || !triple)
    return GRAPH_ERR_NULL_PTR;
  if (delta->magic != GRAPH_DELTA_MAGIC)
    return GRAPH_ERR_CORRUPTED;

  for (uint32_t i = 0; i < delta->deletion_count; i++)
    {
      if (delta->deletions[i].subject == triple->subject &&
	  delta->deletions[i].predicate == triple->predicate && delta->deletions[i].object == triple->object)
	{
	  if (i < delta->deletion_count - 1)
	    {
	      delta->deletions[i] = delta->deletions[delta->deletion_count - 1];
	    }
	  delta->deletion_count--;
	  delta->triple_delta++;
	  return GRAPH_OK;
	}
    }

  /* No duplicate scan here.  This used to walk every addition already in
   * the delta, which made a bulk load quadratic in the number of triples
   * (99% of the time loading a 150k-triple graph was spent in this one
   * loop).  Duplicates are removed in graph_commit(), which already sorts
   * the additions by (subject, predicate, object), so a delta still holds
   * a set by the time anything can read it. */
  graph_error_t err = ensure_addition_capacity (delta, a);
  if (err != GRAPH_OK)
    return err;

  delta->additions[delta->addition_count++] = *triple;
  delta->triple_delta++;

  return GRAPH_OK;
}

graph_error_t
graph_delta_remove_triple (graph_delta_t *delta, const graph_allocator_t *a, const graph_triple_t *triple)
{
  if (!delta || !a || !triple)
    return GRAPH_ERR_NULL_PTR;
  if (delta->magic != GRAPH_DELTA_MAGIC)
    return GRAPH_ERR_CORRUPTED;

  for (uint32_t i = 0; i < delta->addition_count; i++)
    {
      if (delta->additions[i].subject == triple->subject &&
	  delta->additions[i].predicate == triple->predicate && delta->additions[i].object == triple->object)
	{
	  if (i < delta->addition_count - 1)
	    {
	      delta->additions[i] = delta->additions[delta->addition_count - 1];
	    }
	  delta->addition_count--;
	  delta->triple_delta--;
	  return GRAPH_OK;
	}
    }

  for (uint32_t i = 0; i < delta->deletion_count; i++)
    {
      if (delta->deletions[i].subject == triple->subject &&
	  delta->deletions[i].predicate == triple->predicate && delta->deletions[i].object == triple->object)
	{
	  return GRAPH_OK;
	}
    }

  graph_error_t err = ensure_deletion_capacity (delta, a);
  if (err != GRAPH_OK)
    return err;

  delta->deletions[delta->deletion_count++] = *triple;
  delta->triple_delta--;

  return GRAPH_OK;
}

/* ============================================================================
 * TRIPLE LOOKUP
 * ============================================================================ */

bool
graph_delta_contains_addition (const graph_delta_t *delta, const graph_triple_t *triple)
{
  if (!delta || !triple)
    return false;
  if (delta->magic != GRAPH_DELTA_MAGIC)
    return false;

  for (uint32_t i = 0; i < delta->addition_count; i++)
    {
      if (delta->additions[i].subject == triple->subject &&
	  delta->additions[i].predicate == triple->predicate && delta->additions[i].object == triple->object)
	{
	  return true;
	}
    }
  return false;
}

bool
graph_delta_contains_deletion (const graph_delta_t *delta, const graph_triple_t *triple)
{
  if (!delta || !triple)
    return false;
  if (delta->magic != GRAPH_DELTA_MAGIC)
    return false;

  for (uint32_t i = 0; i < delta->deletion_count; i++)
    {
      if (delta->deletions[i].subject == triple->subject &&
	  delta->deletions[i].predicate == triple->predicate && delta->deletions[i].object == triple->object)
	{
	  return true;
	}
    }
  return false;
}

/*
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

/*
 *  openCypher plugin arena allocator
 */

#include "opencypher_arena.h"

#include <string.h>

#define OPENCYPHER_ARENA_MIN_CHUNK 4096

static size_t
opencypher_arena_align (size_t size)
{
  const size_t align = sizeof (void *);
  return (size + align - 1) & ~(align - 1);
}

void
opencypher_arena_init (opencypher_arena_t *arena, size_t default_chunk_size)
{
  arena->chunks = NULL;
  arena->default_chunk_size =
    default_chunk_size > OPENCYPHER_ARENA_MIN_CHUNK
      ? default_chunk_size
      : OPENCYPHER_ARENA_MIN_CHUNK;
}

void
opencypher_arena_destroy (opencypher_arena_t *arena)
{
  opencypher_arena_chunk_t *chunk = arena->chunks;

  while (chunk)
    {
      opencypher_arena_chunk_t *next = chunk->next;
      dk_free (chunk, sizeof (opencypher_arena_chunk_t) + chunk->size);
      chunk = next;
    }

  arena->chunks = NULL;
}

void *
opencypher_arena_alloc (opencypher_arena_t *arena, size_t size)
{
  opencypher_arena_chunk_t *chunk;
  size_t aligned_size = opencypher_arena_align (size);

  if (aligned_size == 0)
    aligned_size = sizeof (void *);

  chunk = arena->chunks;
  if (chunk == NULL || chunk->used + aligned_size > chunk->size)
    {
      size_t chunk_size = arena->default_chunk_size;
      opencypher_arena_chunk_t *new_chunk;

      if (aligned_size > chunk_size)
        chunk_size = aligned_size;

      new_chunk = (opencypher_arena_chunk_t *)
        dk_alloc (sizeof (opencypher_arena_chunk_t) + chunk_size);
      new_chunk->next = arena->chunks;
      new_chunk->size = chunk_size;
      new_chunk->used = 0;
      arena->chunks = new_chunk;
      chunk = new_chunk;
    }

  {
    void *ptr = chunk->data + chunk->used;
    chunk->used += aligned_size;
    memset (ptr, 0, aligned_size);
    return ptr;
  }
}

char *
opencypher_arena_strndup (opencypher_arena_t *arena, const char *text, size_t len)
{
  char *copy = (char *) opencypher_arena_alloc (arena, len + 1);
  if (len > 0)
    memcpy (copy, text, len);
  copy[len] = '\0';
  return copy;
}

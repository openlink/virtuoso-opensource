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
 *
 *  Bump-pointer arena backed by Virtuoso dk_alloc/dk_free. The arena is
 *  intended for one translation/tokenization call and then released as a unit.
 */

#ifndef _OPENCYPHER_ARENA_H
#define _OPENCYPHER_ARENA_H

#include "import_gate_virtuoso.h"

#include <stddef.h>

typedef struct opencypher_arena_chunk_s
{
  struct opencypher_arena_chunk_s *next;
  size_t size;
  size_t used;
  char data[1];
} opencypher_arena_chunk_t;

typedef struct opencypher_arena_s
{
  opencypher_arena_chunk_t *chunks;
  size_t default_chunk_size;
} opencypher_arena_t;

void opencypher_arena_init (opencypher_arena_t *arena, size_t default_chunk_size);
void opencypher_arena_destroy (opencypher_arena_t *arena);
void *opencypher_arena_alloc (opencypher_arena_t *arena, size_t size);
char *opencypher_arena_strndup (opencypher_arena_t *arena, const char *text, size_t len);

#endif /* _OPENCYPHER_ARENA_H */

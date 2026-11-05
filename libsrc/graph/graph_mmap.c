/*
 *  graph_mmap.c
 *
 *  Memory-mapped graph file I/O
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

#include "graph_mmap.h"
#include "graph_internal.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* Platform-specific includes */
#if !defined(GRAPH_OS_WINDOWS) && (defined(GRAPH_OS_LINUX) || defined(GRAPH_OS_MACOS))
#define GRAPH_HAS_MMAP 1
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#endif

#ifdef GRAPH_OS_WINDOWS
#include <windows.h>
#endif

/* ============================================================================
 * CHECKSUM (simple CRC64)
 * ============================================================================ */

static uint64_t crc64_table[256];
static bool crc64_init_done = false;

static void
crc64_init (void)
{
  if (crc64_init_done)
    return;
  const uint64_t poly = 0xC96C5795D7870F42ULL;
  for (int i = 0; i < 256; i++)
    {
      uint64_t crc = i;
      for (int j = 0; j < 8; j++)
	{
	  if (crc & 1)
	    crc = (crc >> 1) ^ poly;
	  else
	    crc >>= 1;
	}
      crc64_table[i] = crc;
    }
  crc64_init_done = true;
}

static uint64_t
crc64_update (uint64_t crc, const void *data, size_t len)
{
  const uint8_t *p = (const uint8_t *) data;
  crc = ~crc;
  for (size_t i = 0; i < len; i++)
    {
      crc = crc64_table[(crc ^ p[i]) & 0xFF] ^ (crc >> 8);
    }
  return ~crc;
}

/* ============================================================================
 * FILE OPERATIONS
 * ============================================================================ */

graph_error_t
graph_mmap_get_info (const char *path, graph_mmap_header_t *out_header)
{
  if (!path || !out_header)
    return GRAPH_ERR_NULL_PTR;

  FILE *f = fopen (path, "rb");
  if (!f)
    return GRAPH_ERR_IO_ERROR;

  size_t read = fread (out_header, 1, sizeof (graph_mmap_header_t), f);
  fclose (f);

  if (read != sizeof (graph_mmap_header_t))
    {
      return GRAPH_ERR_IO_ERROR;
    }

  if (out_header->magic != GRAPH_MMAP_MAGIC)
    {
      return GRAPH_ERR_VERSION_MISMATCH;
    }

  return GRAPH_OK;
}

#ifdef GRAPH_HAS_MMAP

graph_error_t
graph_mmap_open (const char *path, graph_t **out_graph)
{
  if (!path || !out_graph)
    return GRAPH_ERR_NULL_PTR;

  int fd = open (path, O_RDONLY);
  if (fd < 0)
    return GRAPH_ERR_IO_ERROR;

  struct stat st;
  if (fstat (fd, &st) < 0)
    {
      close (fd);
      return GRAPH_ERR_IO_ERROR;
    }

  size_t file_size = (size_t) st.st_size;
  if (file_size < sizeof (graph_mmap_header_t))
    {
      close (fd);
      return GRAPH_ERR_CORRUPTED;
    }

  void *mapped = mmap (NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0);
  close (fd);

  if (mapped == MAP_FAILED)
    {
      return GRAPH_ERR_MMAP_FAILED;
    }

  graph_mmap_header_t *header = (graph_mmap_header_t *) mapped;

  if (header->magic != GRAPH_MMAP_MAGIC)
    {
      munmap (mapped, file_size);
      return GRAPH_ERR_VERSION_MISMATCH;
    }

  if (header->version != GRAPH_MMAP_VERSION)
    {
      munmap (mapped, file_size);
      return GRAPH_ERR_VERSION_MISMATCH;
    }

  graph_t *g;
  graph_error_t err = graph_create (NULL, &g);
  if (err != GRAPH_OK)
    {
      munmap (mapped, file_size);
      return err;
    }

  graph_base_store_t *base = g->base;

  /* graph_create() has just allocated a small store on the heap and the
   * pointers below are about to be replaced by pointers into the
   * mapping, so release the originals first -- at the capacities they
   * were allocated with, which is why this happens before those fields
   * are overwritten.  is_mmap makes graph_base_destroy() munmap and free
   * nothing, so anything still owned here is never released. */
  graph_free (&g->allocator, base->node_ids, base->node_capacity * sizeof (graph_node_id_t));
  graph_free (&g->allocator, base->edge_offsets, (base->node_capacity + 1) * sizeof (uint64_t));
  graph_free (&g->allocator, base->edges, base->edge_capacity * sizeof (graph_edge_t));
  /* The format does not carry the endpoint index arrays.  They stay
   * released and NULL: the neighbour iterator tests for them and walks
   * by id when they are absent, which is slower and right, where an
   * array of the wrong length would have been faster and wrong. */
  graph_free (&g->allocator, base->edge_targets, base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix));
  graph_free (&g->allocator, base->inv_offsets, base->inv_offsets ? (base->node_capacity + 1) * sizeof (uint64_t) : 0);
  graph_free (&g->allocator, base->inv_edges, base->inv_edges ? base->edge_capacity * sizeof (graph_inverse_edge_t) : 0);
  graph_free (&g->allocator, base->inv_sources, base->inv_sources ? base->edge_capacity * GRAPH_IX_SIZE (base->narrow_ix) : 0);
  base->edge_targets = NULL;
  base->inv_offsets = NULL;
  base->inv_edges = NULL;
  base->inv_sources = NULL;

  base->is_mmap = true;
  base->mmap_base = mapped;
  base->mmap_size = file_size;

  base->node_count = header->node_count;
  base->edge_count = header->triple_count;
  base->node_capacity = header->node_count;
  base->edge_capacity = header->triple_count;

  char *data = (char *) mapped;
  base->node_ids = (graph_node_id_t *) (data + header->node_section_offset);
  base->edge_offsets = (uint64_t *) (data + header->edge_offset_section_offset);
  base->edges = (graph_edge_t *) (data + header->edge_section_offset);

  if (header->flags & GRAPH_MMAP_FLAG_INVERSE)
    {
      base->has_inverse = true;
      base->inv_offsets = (uint64_t *) (data + header->inv_offset_section_offset);
      base->inv_edges = (graph_inverse_edge_t *) (data + header->inv_edge_section_offset);
    }

  graph_base_set_dense_descriptor (base);

  g->total_nodes = header->node_count;
  g->total_triples = header->triple_count;

  *out_graph = g;
  return GRAPH_OK;
}

graph_error_t
graph_mmap_close (graph_t *graph)
{
  return graph_destroy (graph);
}

graph_error_t
graph_mmap_sync (graph_t *graph)
{
  if (!graph)
    return GRAPH_ERR_NULL_PTR;

  graph_base_store_t *base = graph->base;
  if (!base->is_mmap || !base->mmap_base)
    {
      return GRAPH_ERR_NOT_INITIALIZED;
    }

  if (msync (base->mmap_base, base->mmap_size, MS_SYNC) < 0)
    {
      return GRAPH_ERR_IO_ERROR;
    }

  return GRAPH_OK;
}

#else /* !GRAPH_HAS_MMAP */

graph_error_t
graph_mmap_open (const char *path, graph_t **out_graph)
{
  (void) path;
  (void) out_graph;
  return GRAPH_ERR_NOT_IMPLEMENTED;
}

graph_error_t
graph_mmap_close (graph_t *graph)
{
  return graph_destroy (graph);
}

graph_error_t
graph_mmap_sync (graph_t *graph)
{
  (void) graph;
  return GRAPH_ERR_NOT_IMPLEMENTED;
}

#endif /* GRAPH_HAS_MMAP */

/* ============================================================================
 * FILE WRITE
 * ============================================================================ */

graph_error_t
graph_write_to_file (const graph_t *graph, const graph_snapshot_t *snapshot, const char *path)
{
  if (!graph || !path)
    return GRAPH_ERR_NULL_PTR;
  (void) snapshot;

  FILE *f = fopen (path, "wb");
  if (!f)
    return GRAPH_ERR_IO_ERROR;

  crc64_init ();

  graph_mmap_header_t header;
  memset (&header, 0, sizeof (header));

  header.magic = GRAPH_MMAP_MAGIC;
  header.version = GRAPH_MMAP_VERSION;
  header.flags = GRAPH_MMAP_FLAG_SORTED;

  const graph_base_store_t *base = graph->base;
  /* The format is a copy of the arrays, and a store whose edges all
   * carry one predicate has no edge-record arrays to copy: the
   * predicate is on the store and the endpoints are indices.  Writing
   * the records back out would mean materialising 32 bytes an edge in a
   * buffer, which is the memory this shape exists to not spend.  So
   * refuse, rather than write a file whose edge section is absent or
   * whose checksum is over nothing. */
  if (!base->edges || (base->has_inverse && !base->inv_edges))
    {
      fclose (f);
      return GRAPH_ERR_NOT_IMPLEMENTED;
    }
  header.node_count = base->node_count;
  header.triple_count = base->edge_count;
  header.predicate_count = graph->pred_registry.count;

  uint64_t offset = GRAPH_MMAP_HEADER_SIZE;

  header.node_section_offset = offset;
  header.node_section_size = base->node_count * sizeof (graph_node_id_t);
  offset += GRAPH_ALIGN_UP (header.node_section_size, 64);

  header.edge_offset_section_offset = offset;
  header.edge_offset_section_size = (base->node_count + 1) * sizeof (uint64_t);
  offset += GRAPH_ALIGN_UP (header.edge_offset_section_size, 64);

  header.edge_section_offset = offset;
  header.edge_section_size = base->edge_count * sizeof (graph_edge_t);
  offset += GRAPH_ALIGN_UP (header.edge_section_size, 64);

  if (base->has_inverse)
    {
      header.flags |= GRAPH_MMAP_FLAG_INVERSE;

      header.inv_offset_section_offset = offset;
      header.inv_offset_section_size = (base->node_count + 1) * sizeof (uint64_t);
      offset += GRAPH_ALIGN_UP (header.inv_offset_section_size, 64);

      header.inv_edge_section_offset = offset;
      header.inv_edge_section_size = base->edge_count * sizeof (graph_inverse_edge_t);
      offset += GRAPH_ALIGN_UP (header.inv_edge_section_size, 64);
    }

  uint64_t checksum = 0;
  checksum = crc64_update (checksum, base->node_ids, header.node_section_size);
  checksum = crc64_update (checksum, base->edge_offsets, header.edge_offset_section_size);
  checksum = crc64_update (checksum, base->edges, header.edge_section_size);
  header.checksum = checksum;

  if (fwrite (&header, sizeof (header), 1, f) != 1)
    {
      fclose (f);
      return GRAPH_ERR_IO_ERROR;
    }

  fseek (f, (long) header.node_section_offset, SEEK_SET);
  fwrite (base->node_ids, sizeof (graph_node_id_t), base->node_count, f);

  fseek (f, (long) header.edge_offset_section_offset, SEEK_SET);
  fwrite (base->edge_offsets, sizeof (uint64_t), base->node_count + 1, f);

  fseek (f, (long) header.edge_section_offset, SEEK_SET);
  fwrite (base->edges, sizeof (graph_edge_t), base->edge_count, f);

  if (base->has_inverse)
    {
      fseek (f, (long) header.inv_offset_section_offset, SEEK_SET);
      fwrite (base->inv_offsets, sizeof (uint64_t), base->node_count + 1, f);

      fseek (f, (long) header.inv_edge_section_offset, SEEK_SET);
      fwrite (base->inv_edges, sizeof (graph_inverse_edge_t), base->edge_count, f);
    }

  fclose (f);
  return GRAPH_OK;
}

graph_error_t
graph_read_from_file (const char *path, graph_t **out_graph)
{
  if (!path || !out_graph)
    return GRAPH_ERR_NULL_PTR;

  FILE *f = fopen (path, "rb");
  if (!f)
    return GRAPH_ERR_IO_ERROR;

  graph_mmap_header_t header;
  if (fread (&header, sizeof (header), 1, f) != 1)
    {
      fclose (f);
      return GRAPH_ERR_IO_ERROR;
    }

  if (header.magic != GRAPH_MMAP_MAGIC || header.version != GRAPH_MMAP_VERSION)
    {
      fclose (f);
      return GRAPH_ERR_VERSION_MISMATCH;
    }

  graph_config_t cfg = GRAPH_CONFIG_DEFAULT;
  cfg.initial_node_capacity = header.node_count > 0 ? header.node_count : 1024;
  cfg.initial_triple_capacity = header.triple_count > 0 ? header.triple_count : 4096;
  cfg.build_inverse_index = (header.flags & GRAPH_MMAP_FLAG_INVERSE) != 0;

  graph_t *g;
  graph_error_t err = graph_create (&cfg, &g);
  if (err != GRAPH_OK)
    {
      fclose (f);
      return err;
    }

  graph_base_store_t *base = g->base;

  fseek (f, (long) header.node_section_offset, SEEK_SET);
  if (fread (base->node_ids, sizeof (graph_node_id_t), header.node_count, f) != header.node_count)
    {
      graph_destroy (g);
      fclose (f);
      return GRAPH_ERR_IO_ERROR;
    }
  base->node_count = header.node_count;

  fseek (f, (long) header.edge_offset_section_offset, SEEK_SET);
  if (fread (base->edge_offsets, sizeof (uint64_t), header.node_count + 1, f) != header.node_count + 1)
    {
      graph_destroy (g);
      fclose (f);
      return GRAPH_ERR_IO_ERROR;
    }

  fseek (f, (long) header.edge_section_offset, SEEK_SET);
  if (fread (base->edges, sizeof (graph_edge_t), header.triple_count, f) != header.triple_count)
    {
      graph_destroy (g);
      fclose (f);
      return GRAPH_ERR_IO_ERROR;
    }
  base->edge_count = header.triple_count;

  /* The inverse index, which graph_write_to_file() writes whenever the
   * store had one and this reader used not to read back.  It has to be
   * read: build_inverse_index is set from the same header flag, so the
   * store claims an inverse index either way, and the row accessors go
   * straight to inv_offsets[] without asking whether anything filled
   * it. */
  if (base->has_inverse)
    {
      fseek (f, (long) header.inv_offset_section_offset, SEEK_SET);
      if (fread (base->inv_offsets, sizeof (uint64_t), header.node_count + 1, f) != header.node_count + 1)
	{
	  graph_destroy (g);
	  fclose (f);
	  return GRAPH_ERR_IO_ERROR;
	}
      fseek (f, (long) header.inv_edge_section_offset, SEEK_SET);
      if (fread (base->inv_edges, sizeof (graph_inverse_edge_t), header.triple_count, f) != header.triple_count)
	{
	  graph_destroy (g);
	  fclose (f);
	  return GRAPH_ERR_IO_ERROR;
	}
    }

  graph_base_set_dense_descriptor (base);
  /* A store read from a file keeps its edge records: the format carries
   * them, and graph_create() allocated them because it could not know
   * the predicate set.  Compacting it would drop them.
   *
   * The format carries the edges but not the endpoint indices, and this
   * store's arrays are heap-allocated at the right size, so fill them
   * rather than leave the allocator's contents in place.  Has to follow
   * the dense descriptor: the rebuild resolves ids through it. */
  graph_base_rebuild_edge_indices (base);

  g->total_nodes = header.node_count;
  g->total_triples = header.triple_count;

  fclose (f);
  *out_graph = g;
  return GRAPH_OK;
}

/* ============================================================================
 * DELTA PERSISTENCE
 * ============================================================================ */

#define DELTA_FILE_MAGIC 0x44454C5446494C45ULL	/* "DELTFILE" */

graph_error_t
graph_delta_save (const graph_t *graph, const char *path)
{
  if (!graph || !path)
    return GRAPH_ERR_NULL_PTR;

  FILE *f = fopen (path, "wb");
  if (!f)
    return GRAPH_ERR_IO_ERROR;

  uint64_t magic = DELTA_FILE_MAGIC;
  fwrite (&magic, sizeof (magic), 1, f);

  graph_delta_t *delta = graph->delta_head;
  while (delta)
    {
      uint32_t add_count = delta->addition_count;
      uint32_t del_count = delta->deletion_count;

      fwrite (&add_count, sizeof (add_count), 1, f);
      fwrite (&del_count, sizeof (del_count), 1, f);

      if (add_count > 0)
	{
	  fwrite (delta->additions, sizeof (graph_triple_t), add_count, f);
	}
      if (del_count > 0)
	{
	  fwrite (delta->deletions, sizeof (graph_triple_t), del_count, f);
	}

      delta = delta->prev;
    }

  uint32_t end_marker = 0xFFFFFFFF;
  fwrite (&end_marker, sizeof (end_marker), 1, f);

  fclose (f);
  return GRAPH_OK;
}

graph_error_t
graph_delta_load (graph_t *graph, const char *path)
{
  if (!graph || !path)
    return GRAPH_ERR_NULL_PTR;

  FILE *f = fopen (path, "rb");
  if (!f)
    return GRAPH_ERR_IO_ERROR;

  uint64_t magic;
  if (fread (&magic, sizeof (magic), 1, f) != 1 || magic != DELTA_FILE_MAGIC)
    {
      fclose (f);
      return GRAPH_ERR_VERSION_MISMATCH;
    }

  while (1)
    {
      uint32_t add_count, del_count;
      if (fread (&add_count, sizeof (add_count), 1, f) != 1)
	break;
      if (add_count == 0xFFFFFFFF)
	break;
      if (fread (&del_count, sizeof (del_count), 1, f) != 1)
	break;

      for (uint32_t i = 0; i < add_count; i++)
	{
	  graph_triple_t t;
	  if (fread (&t, sizeof (t), 1, f) != 1)
	    {
	      fclose (f);
	      return GRAPH_ERR_IO_ERROR;
	    }
	  graph_add_triple (graph, &t);
	}

      for (uint32_t i = 0; i < del_count; i++)
	{
	  graph_triple_t t;
	  if (fread (&t, sizeof (t), 1, f) != 1)
	    {
	      fclose (f);
	      return GRAPH_ERR_IO_ERROR;
	    }
	  graph_remove_triple (graph, &t);
	}

      graph_commit (graph);
    }

  fclose (f);
  return GRAPH_OK;
}
